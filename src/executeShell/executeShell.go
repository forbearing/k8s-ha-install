package main

import (
	"fmt"

	"github.com/bitfield/script"
)

func executeShell() {
	demo()
}

func demo() {
	filename := "/etc/resolv.conf"
	content, err := script.File(filename).String()
	if err != nil {
		panic(err)
	}
	fmt.Println(content)

	numLines, err := script.File(filename).CountLines()
	if err != nil {
		panic(err)
	}
	fmt.Println(numLines)

	filename = "/var/log/system.log"
	numErrors, err := script.File(filename).Match("error").CountLines()
	fmt.Println(numErrors)
}
