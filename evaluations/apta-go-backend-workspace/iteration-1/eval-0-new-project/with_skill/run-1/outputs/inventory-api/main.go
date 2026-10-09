package main

import (
	"github.com/devapta/inventory-api/cmd"
	_ "github.com/devapta/inventory-api/docs"
)

// @title Inventory Api API
// @version 0.0.1
// @BasePath /api
// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name Authorization
func main() {
	cmd.Execute()
}
