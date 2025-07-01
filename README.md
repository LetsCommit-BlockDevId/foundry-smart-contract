## LetsCommit

### Selfhosted Chain

| Contract Name |  Contract Address |
| --- | --- |
| mIDRX | 0x5FbDB2315678afecb367f032d93F642f64180aa3 |
| LetsCommit | 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 | 

Protocol Admin: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

### Monad Testnet Chain

| Contract Name |  Contract Address |
| --- | --- |
| mIDRX | [0xaF82cB6085A05A609F86003B2EC12825a21037A8](https://testnet.monadexplorer.com/address/0xaF82cB6085A05A609F86003B2EC12825a21037A8) |
| LetsCommit | [0xe56E3d0d93eb297998D9eF298533E4e991c8755c](https://testnet.monadexplorer.com/address/0xe56E3d0d93eb297998D9eF298533E4e991c8755c) | 

Protocol Admin: 0xad382a836ACEc5Dd0D149c099D04aA7B49b64cA6

## About Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
