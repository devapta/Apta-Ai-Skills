package configs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"
)

// SlogGormLogger implements gorm/logger.Interface.
// Every SQL query flows through Trace(), which logs via the injected *slog.Logger
// — so queries go to stdout AND Loki (through the otelslog multi-handler).
//
// [GLOBAL SCOPE] — type declaration
type SlogGormLogger struct {
	slog                 *slog.Logger
	level                gormlogger.LogLevel
	slowThreshold        time.Duration
	ignoreRecordNotFound bool
}

// NewSlogGormLogger creates a GORM logger backed by your slog.Logger.
// [GLOBAL SCOPE] — constructor function
func NewSlogGormLogger(slogLogger *slog.Logger) *SlogGormLogger {
	level := gormlogger.Info
	if Env.ServerENV == "prod" {
		level = gormlogger.Error // only log DB errors in prod
	}
	return &SlogGormLogger{
		slog:                 slogLogger,
		level:                level,
		slowThreshold:        200 * time.Millisecond,
		ignoreRecordNotFound: true, // 404s are expected in normal CRUD, don't log as errors
	}
}

// LogMode returns a copy with a different level.
// GORM calls this internally when you do db.Debug() etc.
// [GLOBAL SCOPE] — method
func (l *SlogGormLogger) LogMode(level gormlogger.LogLevel) gormlogger.Interface {
	copy := *l
	copy.level = level
	return &copy
}

// Info / Warn / Error are for GORM's own operational messages (not SQL).
// [GLOBAL SCOPE] — methods
func (l *SlogGormLogger) Info(ctx context.Context, msg string, args ...any) {
	l.slog.InfoContext(ctx, fmt.Sprintf(msg, args...))
}

func (l *SlogGormLogger) Warn(ctx context.Context, msg string, args ...any) {
	l.slog.WarnContext(ctx, fmt.Sprintf(msg, args...))
}

func (l *SlogGormLogger) Error(ctx context.Context, msg string, args ...any) {
	l.slog.ErrorContext(ctx, fmt.Sprintf(msg, args...))
}

// Trace is the KEY method — GORM calls this on EVERY query.
// It receives the context (for trace correlation), the begin time,
// a callback that returns the SQL string + rows affected, and any error.
// [GLOBAL SCOPE] — method
func (l *SlogGormLogger) Trace(ctx context.Context, begin time.Time, fc func() (string, int64), err error) {
	if l.level <= gormlogger.Silent {
		return
	}

	elapsed := time.Since(begin)
	sql, rows := fc()

	// Build structured attributes — these become searchable fields in Loki
	attrs := []any{
		slog.String("query", sql),
		slog.Duration("elapsed", elapsed),
		slog.String("server_id", Env.ServerID),
	}

	// Only include rows if it's meaningful (raw queries sometimes return -1)
	if rows >= 0 {
		attrs = append(attrs, slog.Int64("rows", rows))
	}

	switch {
	// Error path — but skip ErrRecordNotFound if configured to ignore
	case err != nil && l.level >= gormlogger.Error &&
		(!errors.Is(err, gorm.ErrRecordNotFound) || !l.ignoreRecordNotFound):
		l.slog.ErrorContext(ctx, "gorm query failed",
			append(attrs, slog.String("error", err.Error()))...,
		)

	// Slow query warning
	case l.slowThreshold > 0 && elapsed > l.slowThreshold && l.level >= gormlogger.Warn:
		l.slog.WarnContext(ctx, "gorm slow query",
			append(attrs, slog.Duration("threshold", l.slowThreshold))...,
		)

	// Normal query — this is the happy path that logs every SQL statement
	case l.level >= gormlogger.Info:
		l.slog.InfoContext(ctx, "gorm query", attrs...)
	}
}
