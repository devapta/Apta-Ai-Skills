package configs

// Infisical (optional module, disabled by default).
// Uncomment this file and follow the steps in the apta-go-backend skill (references/optional-modules.md).

//
// import (
// 	"context"
// 	"log"
//
// 	infisical "github.com/infisical/go-sdk"
// )
//
// func SetupInfisicalClient() infisical.InfisicalClientInterface {
// 	client := infisical.NewInfisicalClient(context.Background(), infisical.Config{
// 		SiteUrl:          Env.InfisicalBaseURL, // Optional, default is https://api.infisical.com
// 		AutoTokenRefresh: new(true),
// 	})
//
// 	_, err := client.Auth().UniversalAuthLogin(Env.InfisicalClientID, Env.InfisicalClientSecret)
// 	if err != nil {
// 		log.Fatalf("failed authentication for infisical: %s", err.Error())
// 	}
//
// 	log.Println("Connected to infisical")
// 	return client
// }
