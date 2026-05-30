package main

import (
	"log"
	"net/http"
	"os"

	"github.com/proletariat64/dogsquard/backend/internal/task"
)

func main() {
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	store := task.NewStore()
	handler := task.NewHandler(store)

	log.Printf("internal task intake API listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatal(err)
	}
}
