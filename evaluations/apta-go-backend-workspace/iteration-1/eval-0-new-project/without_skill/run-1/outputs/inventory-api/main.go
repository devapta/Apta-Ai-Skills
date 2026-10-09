/*
Copyright © 2026 Apta
*/
package main

import (
	"github.com/devapta/inventory-api/cmd"
	_ "github.com/devapta/inventory-api/docs"
)

// @title Inventory API
// @version 0.0.1
// @description Inventory service API
// @BasePath /api
// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name Authorization
func main() {
	cmd.Execute()
}
