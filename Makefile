# 事前にconvert-jsonを実行しておくこと
# env of vpn
envTarget := vpn

resourceGroupName := $(shell jq -r .resourceGroupName $(envTarget).json)
location := $(shell jq -r .location $(envTarget).json)
vnetName := $(shell jq -r .vpn.vnet.name "$(envTarget)".json)
vnetAddressPrefixes := $(shell jq -r .vpn.vnet.addressPrefixes "$(envTarget)".json)

convert-json:
	npx json5 "$(envTarget)".json5 | jq . > "$(envTarget)".json

test:
	echo "$(resourceGroupName)"
	echo "$(vnetName)"
	echo "$(vnetAddressPrefixes)"

####### resource group #######
# リソースグループの作成
create-resource-group:
	az group create \
		--name "${resourceGroupName}" \
		--location ${location}

# リソースグループの確認
show-resource-group:
	az group list

# リソースグループの削除
delete-resource-group:
	az group delete -y \
		--resource-group "${resourceGroupName}"

####### vnet #######
# vnetを作成
create-vnet:
	az network vnet create \
		--resource-group "${resourceGroupName}" \
		--name "${vnetName}" \
		--address-prefixes "${vnetAddressPrefixes}"

# vnetの確認
show-vnet:
	az network vnet list --resource-group "${resourceGroupName}" | \
		jq -r ' .[] | {name: .name, addressPrefixes: .addressSpace.addressPrefixes[]}'

# vnetの削除
delete-vnet:
	az network vnet delete \
		--resource-group "${resourceGroupName}" \
		--name "${vnetName}"

####### network security group #######
create-nsg-for-vm:
	az network nsg create \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .networkSecurityGroup.vm.name env.json)

create-nsg-for-container:
	az network nsg create \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .networkSecurityGroup.container.name env.json)

####### subnet #######
create-subnet-for-vm:
	az network vnet subnet create \
		--address-prefixes $(shell jq -r .subnet.vm.addressPrefixes env.json) \
		--name $(shell jq -r .subnet.vm.name env.json) \
		--resource-group "${resourceGroupName}" \
		--vnet-name "${vnetName}" \
		--network-security-group $(shell jq -r .networkSecurityGroup.vm.name env.json)

create-subnet-for-container:
	az network vnet subnet create \
		--address-prefixes $(shell jq -r .subnet.container.addressPrefixes env.json) \
		--name $(shell jq -r .subnet.container.name env.json) \
		--resource-group "${resourceGroupName}" \
		--vnet-name "${vnetName}" \
		--network-security-group $(shell jq -r .networkSecurityGroup.container.name env.json)

show-subnet:
	az network vnet subnet list \
		--resource-group "${resourceGroupName}" \
		--vnet-name "${vnetName}" | \
		jq -r '.[] | {name: .name, networkSecurityGroup: .networkSecurityGroup.id}'

####### vm #######
#create-ssh-key: convert-json
#	ssh-keygen \
#		-t rsa \
#		-N "" \
#		-C "azure vm key for $(resourceGroupName)" \
#		-f $(shell jq -r .vm.ssh.keyName env.json)
#	az sshkey create \
#	--location ${location} \
#	--public-key $(shell jq -r .vm.ssh.keyName env.json).pub \
#	--resource-group "${resourceGroupName}" \
#	--name $(shell jq -r .vm.ssh.registerKeyNameInAzure env.json)

create-vm: convert-json
	az vm create \
		--resource-group "${resourceGroupName}" \
		--location ${location} \
		--vnet-name "${vnetName}" \
		--subnet $(shell jq -r .subnet.vm.name env.json) \
		--public-ip-address "" \
		--nsg ""  \
		--name $(shell jq -r .vm.name env.json) \
		--image $(shell jq -r .vm.image env.json) \
		--size $(shell jq -r .vm.size env.json) \
		--storage-sku $(shell jq -r .vm.storageSku env.json) \
		--admin-username $(shell jq -r .vm.adminUserName env.json) \
		--ssh-key-value $(shell jq -r .vm.ssh.keyName env.json).pub \

show-vm:
	az vm show \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .vm.name env.json) | \
		jq -r '{provisioningState: .provisioningState}'

delete-vm:
	az vm delete -y \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .vm.name env.json)

####### vnet gateway #######

create-vpn-resource-group: convert-json
	az group create \
		--name $(shell jq -r .resourceGroupName vpn.json) \
		--location $(shell jq -r .location vpn.json)

# リソースグループの作成
create-vpn-resource-group: convert-json
	az group create \
		--name $(shell jq -r .resourceGroupName vpn.json) \
		--location $(shell jq -r .location vpn.json)

create-vpn-vnet: convert-json
	az network vnet create \
	  --name $(shell jq -r .vpn.vnet.name vpn.json) \
	  --resource-group $(shell jq -r .resourceGroupName vpn.json) \
	  --location $(shell jq -r .location vpn.json) \
	  --address-prefix $(shell jq -r .vpn.vnet.addressPrefixes vpn.json) \
	  --subnet-name $(shell jq -r .vpn.vnet.subnetName vpn.json) \
	  --subnet-prefix $(shell jq -r .vpn.vnet.subnetPrefixes vpn.json)

create-vpn-subnet: convert-json
	az network vnet subnet create \
	  --vnet-name $(shell jq -r .vpn.vnet.name vpn.json) \
	  --name $(shell jq -r .vpn.subnet.name vpn.json) \
	  --resource-group $(shell jq -r .resourceGroupName vpn.json) \
	  --address-prefix $(shell jq -r .vpn.subnet.addressPrefixes vpn.json)

create-vpn-public-ip: convert-json
	az network public-ip create \
	  --name $(shell jq -r .vpn.publicIp.name vpn.json) \
	  --resource-group $(shell jq -r .resourceGroupName vpn.json) \
	  --allocation-method $(shell jq -r .vpn.publicIp.allocationMethod vpn.json)

create-vpn-gateway: convert-json
	az network vnet-gateway create \
	  --name $(shell jq -r .vpn.gateway.name vpn.json) \
	  --location $(shell jq -r .location vpn.json) \
	  --public-ip-address $(shell jq -r .vpn.publicIp.name vpn.json) \
	  --resource-group $(shell jq -r .resourceGroupName vpn.json) \
	  --vnet $(shell jq -r .vpn.vnet.name vpn.json) \
	  --gateway-type $(shell jq -r .vpn.gateway.gatewayType vpn.json) \
	  --sku $(shell jq -r .vpn.gateway.sku vpn.json) \
	  --vpn-type $(shell jq -r .vpn.gateway.vpnType vpn.json) \
	  --no-wait

show-public-ip: convert-json
	az network public-ip show \
      --name $(shell jq -r .vpn.publicIp.name vpn.json) \
      --resource-group $(shell jq -r .resourceGroupName vpn.json)

