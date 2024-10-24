-- List of message patterns to hide and their cooldowns 0 = disabled 60 = one message every 60 sec
messagesToHide = {
  ["New party bot added."] = 0, 
  ["All party bots are casting AoE spells at"] = 10, 
  ["All party bots are now attacking"] = 60,
  ["coming to your position."] = 60, 
  ["has joined the raid group"] = 60,
  ["joins the party."] = 60,
  ["Cannot add more bots. Instance is full."] = 60,  
  ["You should select a character or a creature."] = 60,    
  ["All party bots unpaused."] = 60,
  ["DPS will join in 30 seconds!"] = 60,  
  ["unpaused"] = 60,
  ["staying."] = 60,  
  ["has left the raid group"] = 60,
  ["All bots are moving."] = 60,  
  ["is moving"] = 60,  
  ["is not a party bot."] = 0,    
  ["gameobjects found!"] = 60,    
  ["used the object."] = 60, 
  ["in range of the object."] = 60,   
  ["All party bots are now attacking"] = 5 -- Show this message after 5 seconds if it matches
}
