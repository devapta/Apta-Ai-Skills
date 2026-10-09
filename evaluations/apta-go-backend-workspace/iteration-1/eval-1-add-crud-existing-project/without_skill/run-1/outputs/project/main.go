package main

import (
	"github.com/devapta/shop-api/cmd"
	_ "github.com/devapta/shop-api/docs"
)

// @title Shop Api API
// @version 0.0.1
// @BasePath /api
// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name Authorization
func main() {
	cmd.Execute()
}
