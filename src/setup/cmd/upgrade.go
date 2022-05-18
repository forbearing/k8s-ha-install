package cmd

import (
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var (
	upgradeCmd = &cobra.Command{
		Use:   "upgrade",
		Short: "upgrade k8s cluster",
		Long:  "upgrade k8s cluster",
		Args:  cobra.NoArgs,
		Run: func(cmd *cobra.Command, args []string) {
			log.Info("start upgrade k8s cluster...")
		},
	}
)

func init() {
	rootCmd.AddCommand(upgradeCmd)
}
