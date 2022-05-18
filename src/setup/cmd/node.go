package cmd

import (
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var (
	//nodeName string
	//nodeIP   string
	nodeCmd = &cobra.Command{
		Use:   "node",
		Short: "k8s node management",
		Long:  "k8s node management",
		Run:   func(cmd *cobra.Command, args []string) {},
	}
	nodeAddCmd = &cobra.Command{
		Use:   "add",
		Short: "add k8s node",
		Long:  "add k8s node",
		Args:  cobra.MinimumNArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			log.Info("add k8s node: ", args)
		},
	}
	nodeDelCmd = &cobra.Command{
		Use:   "del",
		Short: "delete k8s node",
		Long:  "delete k8s node",
		Args:  cobra.MinimumNArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			log.Info("delete k8s node: ", args)
		},
	}
)

func init() {
	nodeCmd.AddCommand(nodeAddCmd)
	nodeCmd.AddCommand(nodeDelCmd)
	rootCmd.AddCommand(nodeCmd)

	//nodeCmd.PersistentFlags().StringVarP(&nodeName, "name", "n", "", "k8s node name")
	//nodeCmd.PersistentFlags().StringVarP(&nodeIP, "ip", "i", "", "k8s node ip")
}
