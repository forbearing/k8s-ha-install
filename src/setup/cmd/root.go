package cmd

import (
	"hybfkuf/setup/conf"
	"os"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	rootCmd = &cobra.Command{
		Use:   "setup",
		Short: "start create a kubernetes cluster",
		Long:  "start create a kubernetes cluster",
		Run:   func(cmd *cobra.Command, args []string) {},
	}

	cfgFile string    // 配置文件路径
	k8sConf *conf.K8S // 配置对应的结构体
	debug   bool      // 调式模式
)

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().StringVarP(&cfgFile, "config", "f", "", "k8s config file, default is ./k8s.yaml or conf/k8s.yaml")
	rootCmd.PersistentFlags().BoolVarP(&debug, "debug", "d", false, "enable debug mode")
}
func Execute() {
	cobra.CheckErr(rootCmd.Execute())
}
func initConfig() {
	// 设置日志级别
	if debug {
		log.SetLevel(log.DebugLevel)
	}

	if cfgFile != "" {
		// 读取指定的配置文件
		viper.AddConfigPath(cfgFile)
	} else {
		// 设置配置文件目录(可以设置多个,优先级根据添加顺序来)
		viper.AddConfigPath(".")
		viper.AddConfigPath("./conf")
		viper.AddConfigPath("./config")
		viper.SetConfigType("yaml")
		viper.SetConfigName("k8s")
	}
	// 读取环境变量
	viper.AutomaticEnv()
	if err := viper.ReadInConfig(); err != nil {
		log.Error(err)
		os.Exit(-1)
	}
	// 解析配置文件
	if err := viper.Unmarshal(&k8sConf); err != nil {
		log.Error(err)
		os.Exit(-1)
	}

	log.Debugf("%+v", k8sConf)
	//log.Debugf("%#v", k8sConf)
}
