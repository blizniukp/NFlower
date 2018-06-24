if not tmr.create():alarm(5000, tmr.ALARM_SINGLE, function()
  print("Run app")
  dofile("app.lua")
end)
then
  print("timer error")
end