-- Setup graphical overlay attributes
decoRegion = View.ShapeDecoration.create()
decoRegion:setLineColor(230,230,0)    -- Yellow
decoRegion:setLineWidth(4)

decoFeature = View.ShapeDecoration.create()
decoFeature:setLineColor(75,255,75)    -- Blue
decoFeature:setLineWidth(2)
decoFeature:setPointType("DOT")
decoFeature:setPointSize(5)

decoDot = View.ShapeDecoration.create()
decoDot:setLineColor(230,0,0)         -- Red
decoDot:setPointType("DOT")
decoDot:setPointSize(10)

decoMatch = View.ShapeDecoration.create()
decoMatch:setPointSize(5)
decoMatch:setLineColor(0,230,0) -- Green color scheme for "Teach" mode
decoMatch:setPointType("DOT")


decoTeach = View.ShapeDecoration.create()
decoTeach:setPointSize(5)
decoTeach:setLineColor(0,0,230) -- Blue color scheme for "Teach" mode
decoTeach:setPointType("DOT")