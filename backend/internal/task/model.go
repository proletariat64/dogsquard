package task

import (
	"errors"
	"strings"
	"time"
)

type Priority string

const (
	PriorityLow    Priority = "low"
	PriorityMedium Priority = "medium"
	PriorityHigh   Priority = "high"
)

type Status string

const (
	StatusOpen       Status = "open"
	StatusInProgress Status = "in_progress"
	StatusDone       Status = "done"
)

var (
	ErrInvalidInput = errors.New("invalid input")
	ErrNotFound     = errors.New("task not found")
)

type Task struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Priority    Priority  `json:"priority"`
	Status      Status    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type CreateInput struct {
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Priority    Priority `json:"priority"`
}

type UpdateInput struct {
	Title       *string   `json:"title"`
	Description *string   `json:"description"`
	Priority    *Priority `json:"priority"`
	Status      *Status   `json:"status"`
}

type ValidationError struct {
	Field   string
	Message string
}

func (e ValidationError) Error() string {
	if e.Field == "" {
		return e.Message
	}
	return e.Field + ": " + e.Message
}

func normalizeTitle(title string) (string, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return "", ValidationError{Field: "title", Message: "title is required"}
	}
	return title, nil
}

func normalizePriority(priority Priority) (Priority, error) {
	if priority == "" {
		return PriorityMedium, nil
	}
	if !validPriority(priority) {
		return "", ValidationError{Field: "priority", Message: "priority must be low, medium, or high"}
	}
	return priority, nil
}

func normalizeStatus(status Status) (Status, error) {
	if !validStatus(status) {
		return "", ValidationError{Field: "status", Message: "status must be open, in_progress, or done"}
	}
	return status, nil
}

func validPriority(priority Priority) bool {
	return priority == PriorityLow || priority == PriorityMedium || priority == PriorityHigh
}

func validStatus(status Status) bool {
	return status == StatusOpen || status == StatusInProgress || status == StatusDone
}
