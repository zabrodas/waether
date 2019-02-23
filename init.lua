function startApp()
    print("Starting termometer.lc...")
    dofile('termometer.lc')
end

appTimer=tmr.create()
tmr.register(appTimer,10000,tmr.ALARM_SINGLE,startApp)

print("Application will start in 10s. Send appTimer:stop() to prevent it")

appTimer:start()
