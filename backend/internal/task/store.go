package task

import (
	"sort"
	"strconv"
	"sync"
	"time"
)

type Store struct {
	mu     sync.Mutex
	nextID int
	tasks  map[string]Task
	now    func() time.Time
}

func NewStore() *Store {
	return &Store{
		nextID: 1,
		tasks:  make(map[string]Task),
		now:    func() time.Time { return time.Now().UTC() },
	}
}

func (s *Store) List() []Task {
	s.mu.Lock()
	defer s.mu.Unlock()

	tasks := make([]Task, 0, len(s.tasks))
	for _, item := range s.tasks {
		tasks = append(tasks, item)
	}

	sort.Slice(tasks, func(i, j int) bool {
		left, leftErr := strconv.Atoi(tasks[i].ID)
		right, rightErr := strconv.Atoi(tasks[j].ID)
		if leftErr == nil && rightErr == nil {
			return left < right
		}
		return tasks[i].ID < tasks[j].ID
	})

	return tasks
}

func (s *Store) Create(input CreateInput) (Task, error) {
	title, err := normalizeTitle(input.Title)
	if err != nil {
		return Task{}, err
	}

	priority, err := normalizePriority(input.Priority)
	if err != nil {
		return Task{}, err
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()
	item := Task{
		ID:          strconv.Itoa(s.nextID),
		Title:       title,
		Description: input.Description,
		Priority:    priority,
		Status:      StatusOpen,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	s.nextID++
	s.tasks[item.ID] = item

	return item, nil
}

func (s *Store) Update(id string, input UpdateInput) (Task, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	item, ok := s.tasks[id]
	if !ok {
		return Task{}, ErrNotFound
	}

	if input.Title != nil {
		title, err := normalizeTitle(*input.Title)
		if err != nil {
			return Task{}, err
		}
		item.Title = title
	}

	if input.Description != nil {
		item.Description = *input.Description
	}

	if input.Priority != nil {
		priority, err := normalizePriority(*input.Priority)
		if err != nil {
			return Task{}, err
		}
		item.Priority = priority
	}

	if input.Status != nil {
		status, err := normalizeStatus(*input.Status)
		if err != nil {
			return Task{}, err
		}
		item.Status = status
	}

	item.UpdatedAt = s.now()
	s.tasks[id] = item

	return item, nil
}

func (s *Store) Delete(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.tasks[id]; !ok {
		return ErrNotFound
	}
	delete(s.tasks, id)
	return nil
}
