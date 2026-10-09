package handlers

import (
	"net/http"

	"github.com/devapta/inventory-api/internal/common"
	"github.com/devapta/inventory-api/internal/entities"
	"github.com/devapta/inventory-api/internal/v1/models"
	"github.com/devapta/inventory-api/internal/v1/services"
	"github.com/gin-gonic/gin"
	_ "github.com/morkid/paginate"
)

type RoleHandler struct {
	service services.IRoleService
}

var _ = entities.Role{}

func NewRoleHandler(service services.IRoleService) *RoleHandler {
	return &RoleHandler{
		service: service,
	}
}

// Create godoc
// @Summary			Create role
// @Description		Create a new role
// @Tags 			roles
// @Accept 			json
// @Produce 		json
// @Param 			role	body	models.RoleInput		true	"Role payload"
// @Success			201	{object}	common.Result[uint]
// @Failure			400	{object}	common.Result[string]
// @Failure     	412	{object}  	common.Result[string]
// @Failure			500	{object}	common.Result[string]
// @Security 		ApiKeyAuth
// @Router 			/v1/roles [post]
func (h *RoleHandler) Create(c *gin.Context) {
	var role models.RoleInput
	if err := c.ShouldBindJSON(&role); err != nil {
		_, res := common.ResultErr(err, "failed parsing json")
		c.JSON(http.StatusBadRequest, res)
		return
	}

	id, err := h.service.Create(c.Request.Context(), role)
	if err != nil {
		c.JSON(common.ResultErr(err, "failed creating role"))
		return
	}

	c.JSON(http.StatusCreated, common.ResultOk(id, "Role created"))
}

// Read godoc
// @Summary			List roles
// @Description  	Get a paginated list of roles
// @Tags         	roles
// @Accept       	json
// @Produce      	json
// @Param        	page     query     int     false  "Page"
// @Param        	size     query     int     false  "Size"
// @Param        	sort     query     string  false  "Sort"
// @Param        	filters  query     string  false  "Filter"
// @Success      	200	{object}	paginate.Page{items=[]models.RolePage}
// @Failure      	401 {object}	common.Result[string]
// @Failure      	500 {object}	common.Result[string]
// @Security     	ApiKeyAuth
// @Router 			/v1/roles [get]
func (h *RoleHandler) Read(c *gin.Context) {
	roles, _ := h.service.Read(c)

	c.JSON(http.StatusOK, roles)
}

// Update godoc
// @Summary			Update role
// @Description		Update an existing role's details
// @Tags			roles
// @Accept			json
// @Produce			json
// @Param			id	path	int		true	"Role ID"
// @Param			role	body	models.RoleInput		true	"Updated role details"
// @Success			200	{object}	common.Result[any]
// @Failure			400	{object}	common.Result[string]
// @Failure     	401 {object}  	common.Result[string]
// @Failure			500	{object}	common.Result[string]
// @Security		ApiKeyAuth
// @Router 			/v1/roles/{id} [put]
func (h *RoleHandler) Update(c *gin.Context) {
	id := c.Param("id")

	var role models.RoleInput
	if err := c.ShouldBindJSON(&role); err != nil {
		_, res := common.ResultErr(err, "failed parsing json")
		c.JSON(http.StatusBadRequest, res)
		return
	}

	if err := h.service.Update(c.Request.Context(), id, role); err != nil {
		c.JSON(common.ResultErr(err, "failed updating role"))
		return
	}

	c.JSON(http.StatusOK, common.ResultOk[any](nil, "Role updated"))
}

// Delete godoc
// @Summary			Delete role
// @Description		Delete a role by ID
// @Tags			roles
// @Produce			json
// @Param			id	path	int		true	"Role ID"
// @Success			200	{object}	common.Result[any]
// @Failure      	401 {object}	common.Result[string]
// @Failure			500	{object}	common.Result[string]
// @Security		ApiKeyAuth
// @Router 			/v1/roles/{id} [delete]
func (h *RoleHandler) Delete(c *gin.Context) {
	if err := h.service.Delete(c.Request.Context(), c.Param("id")); err != nil {
		c.JSON(common.ResultErr(err, "failed deleting role"))
		return
	}

	c.JSON(http.StatusOK, common.ResultOk[any](nil, "Role deleted"))
}

// GetByID godoc
// @Summary			Get role by ID
// @Description		Get detailed information about a role by ID
// @Tags			roles
// @Accept       	json
// @Produce      	json
// @Param       	id       path      string  true   "Role ID"
// @Param        	scope    query     string  false  "Scope"
// @Success    		200	{object}	common.Result[entities.Role]
// @Failure    		401 {object}  	common.Result[string]
// @Failure  	    500 {object}  	common.Result[string]
// @Security 	    ApiKeyAuth
// @Router 			/v1/roles/{id} [get]
func (h *RoleHandler) GetByID(c *gin.Context) {
	role, err := h.service.GetByID(c.Request.Context(), c.Param("id"))
	if err != nil {
		c.JSON(common.ResultErr(err, "failed getting role"))
		return
	}

	c.JSON(http.StatusOK, common.ResultOk(role, "Role found"))
}
