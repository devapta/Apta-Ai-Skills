package configs

import (
	"context"
	"errors"
	"fmt"

	"github.com/devapta/inventory-api/internal/enums"
	"go.opentelemetry.io/contrib/instrumentation/runtime"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/log/global"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func SetupOtel(ctx context.Context) (func(context.Context) error, error) {
	res, err := resource.Merge(
		resource.Default(),
		resource.NewSchemaless( // ← CHANGED: was NewWithAttributes(semconv.SchemaURL, ...)
			semconv.ServiceName(Env.OTLPServiceName),
			semconv.ServiceVersion(enums.AppVersion),
			semconv.DeploymentEnvironment(Env.ServerENV),
			attribute.KeyValue{
				Key:   "server_id",
				Value: attribute.StringValue(Env.ServerID),
			},
		),
	)
	if err != nil {
		return nil, fmt.Errorf("otel resource: %w", err)
	}

	// Logger
	exporter, err := otlploghttp.New(ctx) // otlploghttp.WithEndpoint(Env.OTLPEndpoint),
	// otlploghttp.WithInsecure(), // no TLS for local/plain HTTP

	if err != nil {
		return nil, fmt.Errorf("otel log exporter: %w", err)
	}

	loggerProvider := sdklog.NewLoggerProvider(
		sdklog.WithResource(res),
		sdklog.WithProcessor(sdklog.NewBatchProcessor(exporter)),
	)

	global.SetLoggerProvider(loggerProvider)
	// End of logger

	// Traces
	traceExporter, err := otlptracehttp.New(ctx)
	if err != nil {
		return nil, fmt.Errorf("otel trace exporter: %w", err)
	}

	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tracerProvider)

	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))
	// End of traces

	// Metrics
	metricExporter, err := otlpmetrichttp.New(ctx)
	if err != nil {
		return nil, fmt.Errorf("otel metric exporter: %w", err)
	}

	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter)),
	)

	otel.SetMeterProvider(meterProvider)

	if err := runtime.Start(); err != nil {
		return nil, fmt.Errorf("otel runtime metrics: %w", err)
	}
	// End of metrics

	shutdown := func(ctx context.Context) error {
		return errors.Join(
			tracerProvider.Shutdown(ctx), // NEW — flush remaining spans to Tempo
			loggerProvider.Shutdown(ctx), // existing — flush remaining logs to Loki
			meterProvider.Shutdown(ctx),
		)
	}

	return shutdown, nil

}
