/*
Copyright © 2026 Apta
*/
package cmd

import (
	"github.com/devapta/inventory-api/internal/configs"
	"github.com/spf13/cobra"
)

var isDrop bool

// migrateCmd represents the migrate command
var migrateCmd = &cobra.Command{
	Use:   "migrate",
	Short: "Run database migrations and seed the default admin",
	Long:  `Auto-migrates the schema, then seeds the default admin user and Admin role. Use --drop to drop tables first.`,
	Run: func(cmd *cobra.Command, args []string) {
		configs.SetupENV()
		configs.ConnectDB(nil)
		if isDrop {
			configs.DropDB()
		}
		configs.MigrateDB()
	},
}

func init() {
	rootCmd.AddCommand(migrateCmd)
	migrateCmd.PersistentFlags().BoolVar(&isDrop, "drop", false, "Whether to drop the db first")
}
