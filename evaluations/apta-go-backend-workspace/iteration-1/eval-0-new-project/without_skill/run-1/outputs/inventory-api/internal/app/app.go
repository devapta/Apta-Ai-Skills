package app

import (
	"fmt"
	"log"
	"time"

	"github.com/devapta/inventory-api/internal/configs"
	"github.com/devapta/inventory-api/internal/enums"
	"github.com/devapta/inventory-api/internal/v1/middlewares"
	"github.com/devapta/inventory-api/internal/v1/routes"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	swaggerfiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

type App struct {
	apiH  routes.APIHandlers
	slogM *middlewares.SlogMiddleware
}

func New(
	apiH routes.APIHandlers,
	slogM *middlewares.SlogMiddleware,
) *App {
	return &App{
		apiH:  apiH,
		slogM: slogM,
	}
}

func (a *App) Run() error {
	if configs.Env.ServerENV == "prod" {
		gin.SetMode(gin.ReleaseMode)
	}

	// r := gin.Default()
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(otelgin.Middleware(configs.Env.OTLPServiceName))
	r.Use(a.slogM.Logger)

	r.Use(cors.New(cors.Config{
		AllowOrigins:     configs.Env.CorsAllowOrigins,
		AllowMethods:     []string{"POST", "OPTIONS", "GET", "PUT", "PATCH", "DELETE"},
		AllowHeaders:     []string{"Content-Type", "Content-Length", "Accept-Encoding", "X-CSRF-Token", "Authorization", "accept", "origin", "Cache-Control", "X-Requested-With", "X-Refresh-Token"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerfiles.Handler))

	api := r.Group("/api")
	routes.SetupRoutes(api, a.apiH)

	port := fmt.Sprintf(":%s", configs.Env.PORT)
	log.Printf("Listening on %shttp://localhost%s%s", enums.Green, port, enums.Reset)
	log.Printf("Open swagger doc on %shttp://localhost%s/swagger/index.html%s", enums.Purple, port, enums.Reset)
	return r.Run(fmt.Sprintf("0.0.0.0%s", port))
}
