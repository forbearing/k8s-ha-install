package conf

type K8S struct {
	Timezone string `mapstructure:"timezone"`

	Master      []Node `mapstructure:"master"`
	Worker      []Node `mapstructure:"worker"`
	ExtraMaster []Node `mapstructure:"extraMaster"`
	AddWorker   []Node `mapstructure:"addWorker"`

	ControlPlaneendpoint string `mapstructure:"controlPlaneendpoint"`
	SrvNetworkCidr       string `mapstructure:"srvNetworkCidr"`
	SrvNetworkIp         string `mapstructure:"srvNetworkIp"`
	SrvNetworkDnsIp      string `mapstructure:"srvNetworkDnsIp"`
	PodNetworkCidr       string `mapstructure:"podNetworkCidr"`

	KubeRootPass  string `mapstructure:"kubeRootPass"`
	KubeVersion   string `mapstructure:"kubeVersion"`
	KubeProxyMode string `mapstructure:"kubeProxyMode"`

	LinuxSoftwareMirror string `mapstructure:"linuxSoftwareMirror"`

	InstallIngress bool `mapstructure:"installIngress"`
}

type Node struct {
	Host string `mapstructure:"host"`
	IP   string `mapstructure:"ip"`
}
