package configs

import (
	"fmt"
	"log"
	"log/slog"
	"strconv"

	"github.com/devapta/inventory-api/internal/entities"
	"github.com/devapta/inventory-api/internal/enums"
	"github.com/devapta/inventory-api/pkg/jsonb"
	"github.com/uptrace/opentelemetry-go-extra/otelgorm"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB
var dsn string

func ConnectDB(slogLogger *slog.Logger) *gorm.DB {
	p := Env.DBPort
	port, err := strconv.ParseUint(p, 10, 32)
	dsn = fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s search_path=%s sslmode=disable", Env.DBHost, port, Env.DBUser, Env.DBPassword, Env.DBName, Env.DBSchema)

	if err != nil {
		panic("failed to parse database port")
	}

	dbLogger := logger.Default.LogMode(logger.Info)
	if Env.ServerENV == "prod" {
		dbLogger = logger.Default.LogMode(logger.Error)
	}
	if slogLogger != nil {
		dbLogger = NewSlogGormLogger(slogLogger)
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: dbLogger,
	})

	if err != nil {
		panic("failed to connect database")
	}

	if err := db.Use(otelgorm.NewPlugin(
		otelgorm.WithDBName(Env.DBName),
	)); err != nil {
		panic("failed to register otelgorm plugin")
	}

	DB = db

	fmt.Println("Connection Opened to Database")

	return db
}

func MigrateDB() error {
	db := DB

	err := db.AutoMigrate(
		entities.User{},
		entities.Role{},
		entities.UserRole{},
	)

	fmt.Println("Database Migrated")

	seedDefaultUser()
	fmt.Println("Default User Seeded")

	return err
}

func DropDB() error {
	db := DB
	err := db.Migrator().DropTable(
		entities.UserRole{},
		entities.Role{},
		entities.User{},
	)
	fmt.Println("Database Dropped")

	return err
}

func seedDefaultUser() {
	user := entities.User{
		Username: Env.DefaultUser,
		Email:    Env.DefaultEmail,
		Password: Env.DefaultPassword,
	}
	DB.Where("username = ?", user.Username).FirstOrCreate(&user)

	permissions, err := jsonb.New([]string{enums.PermFullAccess})
	if err != nil {
		log.Fatalf("failed seeding role: %s", err.Error())
	}

	role := entities.Role{
		Name:        "Admin",
		Permissions: permissions,
	}
	DB.Where("name = ?", role.Name).FirstOrCreate(&role)

	userRole := entities.UserRole{
		UserID: user.ID,
		RoleID: role.ID,
	}
	DB.Where("role_id = ? and user_id = ?", role.ID, user.ID).FirstOrCreate(&userRole)
}
