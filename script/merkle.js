const { MerkleTree } = require('merkletreejs')
const { bcs, fromHEX, toHEX } = require('@mysten/bcs');
const { sha3_256 } = require('js-sha3');

const data = {
    "0x96c740515c8d2fc6d37ba4dda9391eac18c19cd1d4abc0896df32cf70968b065": {
        "private_allocation": "1000000000",
        "public_allocation": "1000000000"
    },
    "0x540f1e1820db6c1e1b5c02f5bce67daeac57347313800dd83defed8b8b9efc60": {
        "private_allocation": "1000000000",
        "public_allocation": "1000000000"
    },
    "0x8c9422ad99a00923b0edd859816ca9baf8c69e3b0b817f93d278c37974176b0c": {
        "private_allocation": "1000000000",
        "public_allocation": "1000000000"
    },
    "0xf2a6b8c5f8603117751c85c566c949951e1772753a1b78f6f594c4e2fcd7d029": {
        "private_allocation": "1000000000",
        "public_allocation": "1000000000"
    },
    "0x0bf4e8d5c406fd2c759b7f937b8a016d267e7afeb94f1111faab21e950dbd759": {
        "private_allocation": "1000000000",
        "public_allocation": "1000000000"
    }
}

const Address = bcs.bytes(32).transform({
	input: (val) => fromHEX(val),
	output: (val) => toHEX(val),
})

function getNode (
    address, privateAlloc, publicAlloc
) {
    let payload = [
        ...Address.serialize(address).toBytes(),
        ...bcs.u64().serialize(privateAlloc).toBytes(),
        ...bcs.u64().serialize(publicAlloc).toBytes(),
    ];
    return sha3_256(payload);
}

async function main() {
    let leaves = [];
    let keys = Object.keys(data);
    for(let i = 0; i < keys.length; i ++) {
        const key = keys[i];
        let allocs = data[key];
        let node = getNode(key, Number(allocs.private_allocation), Number(allocs.public_allocation));
        leaves.push(node);
    }
    const tree = new MerkleTree(leaves, sha3_256, { sort: true})
    const root = Uint8Array.from(tree.getRoot());
    console.log("root:", root, tree.getRoot().toString('hex'));

    const leaf = getNode("0x0bf4e8d5c406fd2c759b7f937b8a016d267e7afeb94f1111faab21e950dbd759", 1000000000, 1000000000);
    const proof = tree.getHexProof(leaf);
    console.log("leaf", leaf);
    proof.map((el) => {console.log(el)});
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
