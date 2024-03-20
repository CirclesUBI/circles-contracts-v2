import { ethers } from "ethers";

async function main() {
    // provider to get the nonce of deployer key
    const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
    console.log('Provider:', provider.connection.url);
    // deployer wallet
    const deployer = new ethers.wallet(process.env.PRIVATE_KEY, provider);
    console.log('Deployer:', deployer.address);
    // get the nonce of deployer key
    const nonce = await deployer.getTransactionCount();
    console.log('Nonce:', nonce);

    // Calculate the deployment addresses

    // here we need to preserve the order in which we calculate these addresses
    // when we later deploy them in the same order

    const hubAddress_01 = ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce
    });

    const migrationAddress_02 = ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + 1
    });

    const nameRegistryAddress_03 = ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + 2
    });

    const erc20LiftAddress_04 = ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + 3
    });

    const standardTreasuryAddress_05 = ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + 4
    });

    const baseGroupMintPolicyAddress_06 = ethers.utils.getContractAddress({
        from: deployer.address,
        nonce: nonce + 5
    });
    
    // output the addresses for use in the deployment script
    console.log(`${hubAddress_01} ${migrationAddress_02} ${nameRegistryAddress_03} ${erc20LiftAddress_04} ${standardTreasuryAddress_05} ${baseGroupMintPolicyAddress_06}`);
}

main().catch(console.error);