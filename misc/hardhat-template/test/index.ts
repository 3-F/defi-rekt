import { expect } from "chai";
import { defaultAccounts } from "ethereum-waffle";
import { getAddress } from "ethers/lib/utils";
import { ethers } from "hardhat";

describe("Greeter", function () {
  it("desc ...", async function () {
    const accounts = await ethers.getSigners()
    const hacker = await accounts[0].getAddress();

    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy(hacker);

    await greeter.deployed();
    await greeter.greet("Happy Hack");

  });
});
