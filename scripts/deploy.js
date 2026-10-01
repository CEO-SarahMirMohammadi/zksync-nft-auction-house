const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying with:", deployer.address);

  const Gallery = await hre.ethers.getContractFactory(
    "ZKsyncGallery"
  );

  const gallery = await Gallery.deploy();

  await gallery.waitForDeployment();

  const Auction = await hre.ethers.getContractFactory(
    "EnglishAuction"
  );

  const auction = await Auction.deploy(
    await gallery.getAddress(),
    deployer.address,
    250
  );

  await auction.waitForDeployment();

  console.log(
    "ZKsyncGallery:",
    await gallery.getAddress()
  );

  console.log(
    "EnglishAuction:",
    await auction.getAddress()
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});