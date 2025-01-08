#pragma version ^0.4.0

# Create new splits 
#  - emit event
# Charge users 

blueprint: public(address)
owner: public(address)
version: public(uint256)

event NewSplit: 
    split_address: indexed(address)
    admin: indexed(address)
    receiver: indexed(address)
    amount: uint256 
    asset: address

@internal
def new_split(admin: address, asset: address, payers: DynArray[address, 25], total_owed: uint256, receiver: address) -> address:
    addy: address = create_from_blueprint(self.blueprint, admin, asset, payers, total_owed, receiver, code_offset=1)
    log NewSplit(addy, admin, receiver, total_owed, asset)
    return addy 

@internal
def update_blueprint(new_address: address):
    assert msg.sender == self.owner
    self.blueprint = new_address
