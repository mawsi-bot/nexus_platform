// Package cache is a dependency-free Redis client: a small RESP2 codec over
// net.Conn covering GET/SET/DEL/EXPIRE, which is all the feed cache needs (§5.3).
package cache

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Cache is the subset of behaviour callers depend on.
type Cache interface {
	Get(ctx context.Context, key string) (string, bool, error)
	Set(ctx context.Context, key, value string, ttl time.Duration) error
	Del(ctx context.Context, keys ...string) error
}

// Nop is returned when no cache is configured, so callers never branch on nil.
type Nop struct{}

func (Nop) Get(context.Context, string) (string, bool, error)     { return "", false, nil }
func (Nop) Set(context.Context, string, string, time.Duration) error { return nil }
func (Nop) Del(context.Context, ...string) error                  { return nil }

// Redis speaks the wire protocol directly; no client library to audit.
type Redis struct {
	Addr, Password string
	DB             int
	mu             sync.Mutex
	conn           net.Conn
	r              *bufio.Reader
}

// Open dials and authenticates. An unreachable Redis is reported to the caller,
// which decides whether to degrade to Nop.
func Open(ctx context.Context, addr, password string, db int) (*Redis, error) {
	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", addr)
	if err != nil {
		return nil, err
	}
	r := &Redis{Addr: addr, Password: password, DB: db, conn: conn, r: bufio.NewReader(conn)}
	if password != "" {
		if _, err = r.do("AUTH", password); err != nil {
			conn.Close()
			return nil, err
		}
	}
	if db > 0 {
		if _, err = r.do("SELECT", strconv.Itoa(db)); err != nil {
			conn.Close()
			return nil, err
		}
	}
	return r, nil
}

// Close releases the socket.
func (r *Redis) Close() error { return r.conn.Close() }

func (r *Redis) do(args ...string) (any, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.conn == nil {
		return nil, errors.New("cache: closed")
	}
	_ = r.conn.SetDeadline(time.Now().Add(2 * time.Second))
	var b strings.Builder
	fmt.Fprintf(&b, "*%d\r\n", len(args))
	for _, a := range args {
		fmt.Fprintf(&b, "$%d\r\n%s\r\n", len(a), a)
	}
	if _, err := r.conn.Write([]byte(b.String())); err != nil {
		return nil, err
	}
	return r.read()
}

func (r *Redis) read() (any, error) {
	line, err := r.r.ReadString('\n')
	if err != nil {
		return nil, err
	}
	line = strings.TrimSuffix(line, "\r\n")
	if line == "" {
		return nil, errors.New("cache: empty reply")
	}
	switch line[0] {
	case '+':
		return line[1:], nil
	case '-':
		return nil, errors.New(line[1:])
	case ':':
		return strconv.ParseInt(line[1:], 10, 64)
	case '$':
		n, err := strconv.Atoi(line[1:])
		if err != nil {
			return nil, err
		}
		if n < 0 {
			return nil, nil // nil bulk reply
		}
		buf := make([]byte, n+2)
		if _, err = ioReadFull(r.r, buf); err != nil {
			return nil, err
		}
		return string(buf[:n]), nil
	case '*':
		n, err := strconv.Atoi(line[1:])
		if err != nil {
			return nil, err
		}
		out := make([]any, 0, n)
		for i := 0; i < n; i++ {
			v, err := r.read()
			if err != nil {
				return nil, err
			}
			out = append(out, v)
		}
		return out, nil
	}
	return nil, fmt.Errorf("cache: unexpected reply %q", line)
}

func ioReadFull(r *bufio.Reader, buf []byte) (int, error) {
	read := 0
	for read < len(buf) {
		n, err := r.Read(buf[read:])
		read += n
		if err != nil {
			return read, err
		}
	}
	return read, nil
}

// Get returns the value and whether the key existed.
func (r *Redis) Get(ctx context.Context, key string) (string, bool, error) {
	v, err := r.do("GET", key)
	if err != nil {
		return "", false, err
	}
	s, ok := v.(string)
	return s, ok, nil
}

// Set stores a value with a TTL.
func (r *Redis) Set(ctx context.Context, key, value string, ttl time.Duration) error {
	args := []string{"SET", key, value}
	if ttl > 0 {
		args = append(args, "PX", strconv.FormatInt(ttl.Milliseconds(), 10))
	}
	_, err := r.do(args...)
	return err
}

// Del removes keys; missing keys are not an error.
func (r *Redis) Del(ctx context.Context, keys ...string) error {
	if len(keys) == 0 {
		return nil
	}
	_, err := r.do(append([]string{"DEL"}, keys...)...)
	return err
}
