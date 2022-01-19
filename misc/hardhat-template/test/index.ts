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

    await greeter.deployed();
    await greeter.greet("Happy Hack");

  });
});
