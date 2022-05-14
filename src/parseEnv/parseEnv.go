package main

import (
	"fmt"
	"os"

	"github.com/subosito/gotenv"
)

func parseEnv() {
	// 如果你没有给 Load 函数提供任何参数, 那么默认情况下它会加载当前目录下名为 .env 的文件
	err := gotenv.Load("k8s.env")
	if err != nil {
		fmt.Println("error:", err)
	}

	fmt.Println(os.Getenv("MASTER"))
}
