import { expect } from "chai";
import { defaultAccounts } from "ethereum-waffle";
import { BigNumber } from "ethers";
import { getAddress } from "ethers/lib/utils";
import { ethers } from "hardhat";

describe("Luck", function () {
  it("desc ...", async function (done) {
    const accounts = await ethers.getSigners()
    const hacker = await accounts[0];

    const Luck = await ethers.getContractFactory("Luck", hacker);
    const luck = await Luck.deploy();

    await luck.deployed();

    await luck.good_luck({
      from: hacker.address,
      value: "10000000000"
    });

    done();
  });
});
