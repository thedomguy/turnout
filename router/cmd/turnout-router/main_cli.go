//go:build !darwin || !cgo

package main

import (
	"flag"
	"fmt"
	"os"

	"turnout/router/internal/dispatch"
)

func main() {
	urlStr := flag.String("url", "", "Absolute http(s) URL to resolve and open (for CI / non-macOS smoke tests)")
	pick := flag.Bool("pick", false, "Skip policy and open the picker (same as Option-click)")
	explain := flag.Bool("explain", false, "Print the routing decision and open command without opening anything")
	flag.Parse()
	if *urlStr == "" {
		fmt.Fprintf(os.Stderr, "usage: turnout-router -url https://example.com [-pick] [-explain]\n")
		os.Exit(2)
	}
	if *explain {
		out, err := dispatch.Explain(*urlStr, *pick)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println(out)
		return
	}
	if err := dispatch.HandleURL(*urlStr, *pick); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
