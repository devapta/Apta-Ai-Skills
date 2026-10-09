/*
Copyright © 2026 Apta
*/
package cmd

import (
	"context"
	"log"
	"time"

	"github.com/devapta/inventory-api/internal/app"
	"github.com/devapta/inventory-api/internal/configs"
	"github.com/devapta/inventory-api/internal/container"
	"github.com/spf13/cobra"
)

// serveCmd represents the serve command
var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Start the HTTP server",
	Long:  `Starts the Gin HTTP server with OpenTelemetry, slog and Swagger enabled.`,
	Run: func(cmd *cobra.Command, args []string) {
		configs.SetupENV()

		ctx := context.Background()
		shutdown, err := configs.SetupOtel(ctx)
		if err != nil {
			log.Fatalf("failed to set up otel: %v", err)
		}

		defer func() {
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			if err := shutdown(shutdownCtx); err != nil {
				log.Printf("otel shutdown error: %v", err)
			}
		}()

		c := container.New()
		c.Invoke(func(app *app.App) {
			if err := app.Run(); err != nil {
				log.Println(err)
			}
		})
	},
}

func init() {
	rootCmd.AddCommand(serveCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// serveCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// serveCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
