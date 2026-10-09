package container

import (
	"github.com/devapta/shop-api/internal/app"
	"github.com/devapta/shop-api/internal/configs"
	"github.com/devapta/shop-api/internal/v1/handlers"
	"github.com/devapta/shop-api/internal/v1/middlewares"
	"github.com/devapta/shop-api/internal/v1/repositories"
	"github.com/devapta/shop-api/internal/v1/services"
	"go.uber.org/dig"
)

func New() *dig.Container {
	c := dig.New()

	c.Provide(configs.NewSlog)
	c.Provide(configs.ConnectDB)
	// c.Provide(configs.ConnectNats)
	// c.Provide(configs.SetupInfisicalClient)
	// c.Provide(configs.ConnectS3)

	c.Provide(repositories.NewUserRepo, dig.As(new(repositories.IUserRepo)))
	c.Provide(repositories.NewRoleRepo, dig.As(new(repositories.IRoleRepo)))
	c.Provide(repositories.NewUserRoleRepo, dig.As(new(repositories.IUserRoleRepo)))
	// scaffold:repos

	// c.Provide(repositories.NewInfisicalRepo)
	// c.Provide(repositories.NewS3Repo, dig.As(new(common.IS3Repo)))

	c.Provide(services.NewUserService, dig.As(new(services.IUserService)))
	c.Provide(services.NewRoleService, dig.As(new(services.IRoleService)))
	c.Provide(services.NewUserRoleService, dig.As(new(services.IUserRoleService)))
	// scaffold:services

	c.Provide(middlewares.NewAuthMiddleware)
	c.Provide(middlewares.NewSlogMiddleware)

	// c.Provide(consumers.NewExampleConsumer)

	c.Provide(handlers.NewUserHandler)
	c.Provide(handlers.NewRoleHandler)
	c.Provide(handlers.NewUserRoleHandler)
	// scaffold:handlers

	c.Provide(app.New)

	return c
}
