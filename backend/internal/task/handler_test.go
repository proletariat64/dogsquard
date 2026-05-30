package task

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthz(t *testing.T) {
	handler := NewHandler(NewStore())

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var body map[string]string
	decodeResponse(t, rec, &body)
	if body["status"] != "ok" {
		t.Fatalf("status body = %q, want ok", body["status"])
	}
	assertJSONContentType(t, rec)
}

func TestAllowsLocalFrontendOrigins(t *testing.T) {
	handler := NewHandler(NewStore())

	for _, origin := range []string{"http://127.0.0.1:5173", "http://127.0.0.1:4173"} {
		t.Run(origin, func(t *testing.T) {
			rec := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
			req.Header.Set("Origin", origin)
			handler.ServeHTTP(rec, req)

			if got := rec.Header().Get("Access-Control-Allow-Origin"); got != origin {
				t.Fatalf("access-control-allow-origin = %q, want %q", got, origin)
			}
		})
	}
}

func TestListTasksEmpty(t *testing.T) {
	handler := NewHandler(NewStore())

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/tasks", nil)
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", rec.Code, http.StatusOK)
	}
	assertJSONContentType(t, rec)

	var tasks []Task
	decodeResponse(t, rec, &tasks)
	if len(tasks) != 0 {
		t.Fatalf("task count = %d, want 0", len(tasks))
	}
}

func TestCreateTaskDefaultsAndList(t *testing.T) {
	handler := NewHandler(NewStore())

	create := requestJSON(t, handler, http.MethodPost, "/api/tasks", map[string]string{
		"title":       " Write docs ",
		"description": "Prepare example app docs",
	})
	if create.Code != http.StatusCreated {
		t.Fatalf("create status = %d, want %d: %s", create.Code, http.StatusCreated, create.Body.String())
	}

	var item Task
	decodeResponse(t, create, &item)
	if item.ID == "" {
		t.Fatal("created task has empty id")
	}
	if item.Title != "Write docs" {
		t.Fatalf("title = %q, want trimmed title", item.Title)
	}
	if item.Priority != PriorityMedium {
		t.Fatalf("priority = %q, want %q", item.Priority, PriorityMedium)
	}
	if item.Status != StatusOpen {
		t.Fatalf("status = %q, want %q", item.Status, StatusOpen)
	}
	if item.CreatedAt.IsZero() || item.UpdatedAt.IsZero() {
		t.Fatal("created task timestamps must be set")
	}

	list := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/tasks", nil)
	handler.ServeHTTP(list, req)
	if list.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", list.Code, http.StatusOK)
	}

	var tasks []Task
	decodeResponse(t, list, &tasks)
	if len(tasks) != 1 {
		t.Fatalf("task count = %d, want 1", len(tasks))
	}
}

func TestCreateTaskValidation(t *testing.T) {
	handler := NewHandler(NewStore())

	tests := []struct {
		name string
		body map[string]string
	}{
		{
			name: "missing title",
			body: map[string]string{"priority": "medium"},
		},
		{
			name: "blank title",
			body: map[string]string{"title": "   ", "priority": "medium"},
		},
		{
			name: "invalid priority",
			body: map[string]string{"title": "Task", "priority": "urgent"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := requestJSON(t, handler, http.MethodPost, "/api/tasks", tt.body)
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
			}

			var body map[string]string
			decodeErrorResponse(t, rec, &body)
			if body["code"] != "validation_error" || body["message"] == "" {
				t.Fatalf("error response = %#v, want validation_error with message", body)
			}
		})
	}
}

func TestCreateTaskInvalidJSON(t *testing.T) {
	handler := NewHandler(NewStore())

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/tasks", strings.NewReader(`{"title":`))
	req.Header.Set("Content-Type", "application/json")
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
	assertJSONContentType(t, rec)

	var body map[string]string
	decodeErrorResponse(t, rec, &body)
	if body["code"] != "invalid_json" {
		t.Fatalf("error code = %q, want invalid_json", body["code"])
	}
}

func TestUpdateTaskStatusAndValidation(t *testing.T) {
	handler := NewHandler(NewStore())
	created := createTask(t, handler, "Review PR")

	updateFields := requestJSON(t, handler, http.MethodPatch, "/api/tasks/"+created.ID, map[string]string{
		"title":       " Review updated PR ",
		"description": "Updated description",
		"priority":    "high",
	})
	if updateFields.Code != http.StatusOK {
		t.Fatalf("update fields status = %d, want %d: %s", updateFields.Code, http.StatusOK, updateFields.Body.String())
	}

	var fieldUpdate Task
	decodeResponse(t, updateFields, &fieldUpdate)
	if fieldUpdate.Title != "Review updated PR" {
		t.Fatalf("title = %q, want trimmed updated title", fieldUpdate.Title)
	}
	if fieldUpdate.Description != "Updated description" {
		t.Fatalf("description = %q, want updated description", fieldUpdate.Description)
	}
	if fieldUpdate.Priority != PriorityHigh {
		t.Fatalf("priority = %q, want %q", fieldUpdate.Priority, PriorityHigh)
	}

	rec := requestJSON(t, handler, http.MethodPatch, "/api/tasks/"+created.ID, map[string]string{
		"status": "in_progress",
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("update status = %d, want %d: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var updated Task
	decodeResponse(t, rec, &updated)
	if updated.Status != StatusInProgress {
		t.Fatalf("status = %q, want %q", updated.Status, StatusInProgress)
	}
	if !updated.UpdatedAt.After(updated.CreatedAt) && !updated.UpdatedAt.Equal(updated.CreatedAt) {
		t.Fatal("updated_at must not be before created_at")
	}

	bad := requestJSON(t, handler, http.MethodPatch, "/api/tasks/"+created.ID, map[string]string{
		"status": "blocked",
	})
	if bad.Code != http.StatusBadRequest {
		t.Fatalf("invalid update status = %d, want %d", bad.Code, http.StatusBadRequest)
	}

	var body map[string]string
	decodeErrorResponse(t, bad, &body)
	if body["code"] != "validation_error" {
		t.Fatalf("error code = %q, want validation_error", body["code"])
	}
}

func TestMissingTaskReturnsNotFound(t *testing.T) {
	handler := NewHandler(NewStore())

	update := requestJSON(t, handler, http.MethodPatch, "/api/tasks/missing", map[string]string{
		"status": "done",
	})
	if update.Code != http.StatusNotFound {
		t.Fatalf("missing update status = %d, want %d", update.Code, http.StatusNotFound)
	}
	var updateBody map[string]string
	decodeErrorResponse(t, update, &updateBody)
	if updateBody["code"] != "not_found" {
		t.Fatalf("missing update code = %q, want not_found", updateBody["code"])
	}

	deleteRec := httptest.NewRecorder()
	deleteReq := httptest.NewRequest(http.MethodDelete, "/api/tasks/missing", nil)
	handler.ServeHTTP(deleteRec, deleteReq)
	if deleteRec.Code != http.StatusNotFound {
		t.Fatalf("missing delete status = %d, want %d", deleteRec.Code, http.StatusNotFound)
	}
	var deleteBody map[string]string
	decodeErrorResponse(t, deleteRec, &deleteBody)
	if deleteBody["code"] != "not_found" {
		t.Fatalf("missing delete code = %q, want not_found", deleteBody["code"])
	}
}

func TestUnsupportedMethodReturnsJSONError(t *testing.T) {
	handler := NewHandler(NewStore())

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPut, "/api/tasks", nil)
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusMethodNotAllowed)
	}
	if rec.Header().Get("Allow") != "GET, POST" {
		t.Fatalf("allow = %q, want GET, POST", rec.Header().Get("Allow"))
	}
	assertJSONContentType(t, rec)

	var body map[string]string
	decodeErrorResponse(t, rec, &body)
	if body["code"] != "method_not_allowed" {
		t.Fatalf("error code = %q, want method_not_allowed", body["code"])
	}
}

func TestDeleteTask(t *testing.T) {
	handler := NewHandler(NewStore())
	created := createTask(t, handler, "Delete me")

	deleteRec := httptest.NewRecorder()
	deleteReq := httptest.NewRequest(http.MethodDelete, "/api/tasks/"+created.ID, nil)
	handler.ServeHTTP(deleteRec, deleteReq)
	if deleteRec.Code != http.StatusNoContent {
		t.Fatalf("delete status = %d, want %d", deleteRec.Code, http.StatusNoContent)
	}

	list := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/tasks", nil)
	handler.ServeHTTP(list, req)

	var tasks []Task
	decodeResponse(t, list, &tasks)
	if len(tasks) != 0 {
		t.Fatalf("task count after delete = %d, want 0", len(tasks))
	}
}

func createTask(t *testing.T, handler http.Handler, title string) Task {
	t.Helper()

	rec := requestJSON(t, handler, http.MethodPost, "/api/tasks", map[string]string{
		"title":    title,
		"priority": "medium",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("create status = %d, want %d: %s", rec.Code, http.StatusCreated, rec.Body.String())
	}

	var item Task
	decodeResponse(t, rec, &item)
	return item
}

func requestJSON(t *testing.T, handler http.Handler, method string, path string, body any) *httptest.ResponseRecorder {
	t.Helper()

	payload, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	handler.ServeHTTP(rec, req)
	return rec
}

func decodeResponse(t *testing.T, rec *httptest.ResponseRecorder, target any) {
	t.Helper()

	if err := json.NewDecoder(rec.Body).Decode(target); err != nil {
		t.Fatalf("decode response: %v; body=%q", err, rec.Body.String())
	}
}

func decodeErrorResponse(t *testing.T, rec *httptest.ResponseRecorder, target *map[string]string) {
	t.Helper()

	var envelope struct {
		Error map[string]string `json:"error"`
	}
	decodeResponse(t, rec, &envelope)
	*target = envelope.Error
}

func assertJSONContentType(t *testing.T, rec *httptest.ResponseRecorder) {
	t.Helper()

	if contentType := rec.Header().Get("Content-Type"); contentType != "application/json" {
		t.Fatalf("content-type = %q, want application/json", contentType)
	}
}
