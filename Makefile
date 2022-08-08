# 事前にconvert-jsonを実行しておくこと
resourceGroupName := $(shell jq -r .resourceGroupName env.json)
vnetName := $(shell jq -r .vpn.vnet.name env.json)
vnetAddressPrefixes := $(shell jq -r .vpn.vnet.addressPrefixes env.json)

convert-json:
	npx json5 env.json5 | jq . > env.json

test:
	echo "$(resourceGroupName)"
	echo "$(vnetName)"
	echo "$(vnetAddressPrefixes)"

####### resource group #######
# リソースグループの作成
create-resource-group:
	az group create \
		--name "${resourceGroupName}" \
		--location japaneast

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
create-nsg-vm:
	az network nsg create \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .networkSecurityGroup.vm.name env.json)

create-nsg-container:
	az network nsg create \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .networkSecurityGroup.container.name env.json)

####### subnet #######
create-subnet-vm:
	az network vnet subnet create \
		--address-prefixes $(shell jq -r .subnet.vm.addressPrefixes env.json) \
		--name $(shell jq -r .subnet.vm.name env.json) \
		--resource-group "${resourceGroupName}" \
		--vnet-name "${vnetName}" \
		--network-security-group $(shell jq -r .networkSecurityGroup.vm.name env.json)

create-subnet-container:
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
create-vm:
	az vm create \
		--resource-group "${resourceGroupName}" \
		--location japaneast \
		--vnet-name "${vnetName}" \
		--subnet $(shell jq -r .subnet.vm.name env.json) \
		--public-ip-address "" \
		--nsg ""  \
		--name $(shell jq -r .vm.name env.json) \
		--image $(shell jq -r .vm.image env.json) \
		--size $(shell jq -r .vm.size env.json) \
		--storage-sku $(shell jq -r .vm.storageSku env.json)

show-vm:
	az vm show \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .vm.name env.json) | \
		jq -r '{provisioningState: .provisioningState}'

delete-vm:
	az vm delete -y \
		--resource-group "${resourceGroupName}" \
		--name $(shell jq -r .vm.name env.json)
