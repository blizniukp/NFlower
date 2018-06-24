-----------------------------------------------
--- Set Variables ---
-----------------------------------------------
measurement = {}

dofile"config.lua"

-----------------------------------------------

if adc.force_init_mode(adc.INIT_ADC)
then
  node.restart()
  return
end

--- Initialize arrays ---

for i=1, AFLOWER_MAX_INPUTS do
    measurement[i] = 0.0
end


--- Initialize GPIO ---
for i=1, 2 do
    print("Set GPIO " .. tostring(i) .. " to Output - Low.")
    gpio.mode(i, gpio.OUTPUT)
    gpio.write(i, gpio.LOW)
end

gpio.mode(CD4051BE_PIN_A, gpio.OUTPUT)
gpio.mode(CD4051BE_PIN_B, gpio.OUTPUT)
gpio.mode(CD4051BE_PIN_C, gpio.OUTPUT)
gpio.write(CD4051BE_PIN_A, gpio.LOW)
gpio.write(CD4051BE_PIN_B, gpio.LOW)
gpio.write(CD4051BE_PIN_C, gpio.LOW)
    
function setPower(c, b, a)
    gpio.write(1, gpio.LOW)
    gpio.write(2, gpio.LOW)
       
    pinNo = (c * 4) +(b * 2) + a

    if pinNo <= 3 then
        print("Set GPIO 1 to High")
        gpio.write(1, gpio.HIGH)
    else
        print("Set GPIO 2 to High")
        gpio.write(2, gpio.HIGH)
    end
    
    gpio.write(CD4051BE_PIN_A, a);
    gpio.write(CD4051BE_PIN_B, b);
    gpio.write(CD4051BE_PIN_C, c);

    tmr.delay(50000)
end

powerPinNo=1;
for rep=1, AFLOWER_MAX_MEASURE_REPEAT do
    measureIdx=1;
    for c=0, 1 do
        for b=0, 1 do
            for a=0, 1 do
                setPower(c, b, a)
                mval = adc.read(0)
                measurement[measureIdx] = measurement[measureIdx] + mval
                print(tostring(rep) .. ":[" .. tostring(measureIdx) .. "] A:" .. a .. " B: " .. b .. " C: " .. c .. " MVAL: " .. tostring(mval) .. " MOISTURE: " .. tostring(measurement[measureIdx]))
                measureIdx = measureIdx + 1
            end
        end
    end
end

for i=1, 2 do
    print("Set GPIO " .. tostring(i) .. " to Output - Low.")
    gpio.mode(i, gpio.OUTPUT)
    gpio.write(i, gpio.LOW)
end         
gpio.write(CD4051BE_PIN_A, gpio.LOW)
gpio.write(CD4051BE_PIN_B, gpio.LOW)
gpio.write(CD4051BE_PIN_C, gpio.LOW)

--- Connect to the wifi network ---
wifi.setmode(wifi.STATION) 
wifi.setphymode(WIFI_SIGNAL_MODE)
wifi.sta.config({ssid=WIFI_SSID, pwd=WIFI_PASSWORD})
wifi.sta.connect()

if ESP8266_IP ~= "" then
 wifi.sta.setip({ip=ESP8266_IP,netmask=ESP8266_NETMASK,gateway=ESP8266_GATEWAY})
end

-----------------------------------------------
--- PREPARE MQTT MESSAGE ---
mInfo = "{ \"deviceSerial\":" .. tostring(SERIAL_NUM) .. ", "
mInfo = mInfo .. "\"fw\":" .. FIRMWARE_VERSION
for i=1, AFLOWER_MAX_INPUTS do
    value = measurement[i] / AFLOWER_MAX_MEASURE_REPEAT
    mInfo = mInfo .. ",\"SM_" .. tostring(i - 1) .. "\":" .. value
    
end
mInfo = mInfo .. "}"
print(mInfo)
-----------------------------------------------

function goDeepSleep()
    print("Enter deep sleep")
    node.dsleep(60 * 60 * 1000000)--- wait 1 hour 
end

function connected(m)
    print("Connected. Publish message") 
    pubResult = m:publish("/NFlower/" .. tostring(SERIAL_NUM) .. "/newMeasure","test",0,0)
    print("Publish result: " .. tostring(pubResult))
    goDeepSleep()
end

function connectToBroker()
    print("Connecting to MQTT Broker...\n")
    m = mqtt.Client(tostring(SERIAL_NUM), 120)
    m:on("connect", function(con) print ("m -connected") end)
    m:on("offline", function(con) print ("m - offline") end)

    m:connect(MQTT_BROKER_IP, MQTT_BROKER_PORT, 0, function(conn) 
      print("connected")
      m:subscribe("/NFlower/" .. tostring(SERIAL_NUM) .. "/request",0, function(conn) 
      m:publish("/NFlower/" .. tostring(SERIAL_NUM) .. "/newMeasure",mInfo,0,0, function(conn) 
          print("sent") 
          goDeepSleep()
        end)
      end)
    end)
end

tmr.alarm(0, 1000, 1, function()
   if wifi.sta.getip() == nil then
      print("Connecting to AP...\n")
   else
      ip, nm, gw=wifi.sta.getip()
      print("IP Info: \nIP Address: ",ip)
      print("Netmask: ",nm)
      print("Gateway Addr: ",gw,'\n')
      tmr.stop(0)
      connectToBroker()
   end
end)
