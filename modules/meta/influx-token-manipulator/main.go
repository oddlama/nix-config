package main

import (
	"encoding/json"
	"fmt"
	"go.etcd.io/bbolt"
	"io/ioutil"
	"os"
	"regexp"
	"strings"
)

var tokenPaths = map[string]string{
  // Add token secrets here or in separate file
}

func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: ./influx-token-manipulator <influxd.bolt>\n")
		os.Exit(1)
	}

	dbPath := os.Args[1]

	db, err := bbolt.Open(dbPath, 0666, nil)
	if err != nil {
		fmt.Printf("Error opening database: %v\n", err)
	}
	defer db.Close()

	err = db.Update(func(tx *bbolt.Tx) error {
		bucket := tx.Bucket([]byte("authorizationsv1"))
		if bucket == nil {
			fmt.Println("Bucket 'authorizationsv1' not found.")
			os.Exit(1)
		}

		return bucket.ForEach(func(k, v []byte) error {
			var obj map[string]interface{}
			if err := json.Unmarshal(v, &obj); err != nil {
				fmt.Printf("Error unmarshalling JSON: %v\n", err)
				return nil // Continue processing other rows
			}

			description, ok := obj["description"].(string)
			if !ok {
				return nil // Skip if description is not present
			}

			identifierRegex := regexp.MustCompile(`[0-9a-f]{32}`)
			match := identifierRegex.FindString(description)
			if match == "" {
				return nil // Skip if description doesn't match regex
			}

			tokenPath, found := tokenPaths[match]
			if !found {
				return nil // Skip if match is not in lookup
			}
			delete(tokenPaths, match) // Remove entry from the map

			content, err := ioutil.ReadFile(tokenPath)
			if err != nil {
				fmt.Printf("Error reading new token file: %v\n", err)
				return nil // Continue processing other rows
			}
			newToken := strings.TrimSpace(string(content)) // Remove leading and trailing whitespace

			oldToken, ok := obj["token"].(string)
			if !ok {
				fmt.Printf("Skipping invalid token without .token\n")
				return nil // Skip if token is not present
			}

			if oldToken == newToken {
				return nil // Skip if token is already up-to-date
			}

			obj["token"] = newToken
			updatedValue, err := json.Marshal(obj)
			if err != nil {
				fmt.Printf("Error marshalling updated JSON: %v\n", err)
				return nil // Continue processing other rows
			}

			if err := bucket.Put(k, updatedValue); err != nil {
				fmt.Printf("Error updating bucket: %v\n", err)
				return nil // Continue processing other rows
			}

			fmt.Printf("Updated token: '%s'\n", description)
			return nil
		})
	})
	if err != nil {
		fmt.Printf("Error during transaction: %v", err)
	}

	// Check if any tokens were not processed
	if len(tokenPaths) > 0 {
		fmt.Println("Warning: The following tokens were not encountered:")
		for token := range tokenPaths {
			fmt.Printf("- %s\n", token)
		}
	}
}
