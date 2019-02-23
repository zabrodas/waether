function on_wifi_connected(SSID,BSSID,channel)
    print("WiFi connected to:",SSID,BSSID,channel)
end
function on_wifi_disconnected(SSID,BSSID,reason)
    print("WiFi disconnected from:",SSID,BSSID,reason)
end
function on_wifi_got_ip(IP,netmask,gateway)
    print("WiFi got IP:",IP,netmask,gateway)
end

weatherRequest="https://api.darksky.net/forecast/062203217cbe6cc8558d187d49692b0c/59.934945,30.373961?exclude=minutely,hourly,daily,alerts,flags&units=si"

requestTimer=tmr.create()


wifi.setmode(wifi.STATION);
station_cfg={}
station_cfg.ssid="gzabrodina"
station_cfg.pwd="pusya756nadya"
station_cfg.auto=true
station_cfg.save=true
station_cfg.connected_cb=on_wifi_connected
station_cfg.disconnected_cb=on_wifi_disconnected
station_cfg.got_ip_cb=on_wifi_got_ip
wifi.sta.config(station_cfg)

function onWeatherReceived(code,data,headers)
    print("Weather:",code,data,headers)
    local ok,wd=pcall(sjson.decode,data)
    local temp=nil
    if ok then 
        for k,v in pairs(wd) do print(k,v) end
        if wd.currently~=nil and wd.currently.temperature~=nil then
            temp=tonumber(wd.currently.temperature)
        end
    else
        print("Unformatted data:",data)
    end
    print("temp=",temp)
    if temp~=nil then
        motorIndicateTemp(temp)
        requestTimer:interval(10000)
    else
        requestTimer:interval(60000*5)
    end
    requestTimer:start()
end

function getWeather()
    http.get(weatherRequest,nil,onWeatherReceived)
end

motorSignals={
    {gpio.HIGH,gpio.LOW ,gpio.HIGH,gpio.LOW },
    {gpio.LOW ,gpio.HIGH,gpio.HIGH,gpio.LOW },
    {gpio.LOW ,gpio.HIGH,gpio.LOW ,gpio.HIGH},
    {gpio.HIGH,gpio.LOW ,gpio.LOW ,gpio.HIGH}
}
motorPins={1,2,3,4}
motorStep=1
motorCurrPos=0
motorStepsPerRevolution=128*16
motorStepsPerAngleGrad=motorStepsPerRevolution/360
motorScaleMinTemp=-60
motorScaleMaxTemp=60
motorScaleAngle=180
motorStepsInScale=motorScaleAngle*motorStepsPerAngleGrad
motorStepsPerGradTemp=motorStepsInScale/(motorScaleMaxTemp-motorScaleMinTemp)

function motorWriteState()
    for i=1,4 do
        gpio.write(motorPins[i], motorSignals[motorStep][i])
    end
    tmr.delay(1000)
end
function motorStart()
    motorWriteState()
end
function motorStop()
    for i=1,4 do
        gpio.write(motorPins[i], gpio.LOW)
    end
    tmr.delay(1000)
end
function motorNext()
    motorStart()
    motorStep=motorStep+1
    if motorStep>table.getn(motorSignals) then
        motorStep=1
    end
    motorWriteState()
    motorCurrPos=motorCurrPos+1
end
function motorPrev()
    motorStart()
    motorStep=motorStep-1
    if motorStep<1 then
        motorStep=table.getn(motorSignals)
    end
    motorWriteState()
    motorCurrPos=motorCurrPos-1
end
function initMotor()
    for i=1,4 do
        gpio.mode(motorPins[i], gpio.OUTPUT)
    end
    motorStep=1
    motorStart()
    motorStop()
end

function motorMoveTo(pos)
    motorStart()
    while pos>motorCurrPos do
        motorNext()
    end
    while pos<motorCurrPos do
        motorPrev()
    end
    motorStop()
    print("motorPos=",motorCurrPos)
end
function motorTempToPos(grad)
    return grad*motorStepsPerGradTemp
end
function motorIndicateTemp(grad)
    motorMoveTo(motorTempToPos(grad))
end
function motorHome()
    motorIndicateTemp(motorScaleMinTemp-motorScaleMaxTemp)
    motorCurrPos=motorTempToPos(motorScaleMinTemp)
    print("motorPos=",motorCurrPos)
end

--initMotor()
--motorHome()

--requestTimer:register(10000, tmr.ALARM_SEMI, getWeather)
--requestTimer:start()
