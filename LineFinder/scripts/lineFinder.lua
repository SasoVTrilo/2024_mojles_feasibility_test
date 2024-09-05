
require("Decorations")

test_viewer1 = View.create("testDisplay1")
test_viewer2= View.create("testDisplay2")
test_viewer3D= View.create("testDisplay3D")


local xy_pix_measurement = 1

--- Get lines
---@param image Image
local function extractEdgePoints(image)

  local start_region = Point.create(0, 128)
  local mid_point = Point.create(0, 394)
  local image_width, image_height  = image:getSize()
  local end_region = Point.create(image_width-1, 680)
  local max_dist = 50
  local y_profiles = {
    top={},
    mid={},
    bot={},
  }
  local prof_count = 1
  local regions = {top=start_region:getY(), mid=mid_point:getY(),bot=end_region:getY() }
  test_viewer1:clear()
  test_viewer1:addImage(image)
  test_viewer1:present()
  for label, y in pairs(regions) do
      prof_count = 1
      local prev_x = 1
      local x_profiles = {}
    for x = start_region:getX(),end_region:getX() do
      local pixel = image:getPixel(x,y,'RAW_COORDINATES')
      if pixel > 0 then
        if (prev_x ~= 1) and (x > prev_x + max_dist) then
          prof_count = prof_count + 3
        elseif x>prev_x+3 then
          x_profiles[prof_count] = x
          prof_count = prof_count + 1
          prev_x = x
          local point = Point.create(x,y)
          test_viewer1:addPoint(point, decoDot)
        end
      end
    end
    y_profiles[label] = {y=y, x_points = x_profiles}
  end
  test_viewer1:present()
  return y_profiles
end

local function extractRotatedEdgeFromRegion(image, regions, origin)
  local bottomEdgePoints = {}
  local topEdgePoints = {}

  local bot_x_arr = {}
  local top_x_arr = {}
  local y_arr = {}

  local x_bot_min = 9999
  local x_top_min = 9999
  local y_min = 9999

  local outlier_crit = 25
  local prevBotX = nil
  local prevTopX = nil
  for y,x_arr in pairs(regions) do
    local bottom_x = x_arr[1]
    local top_x = x_arr[#x_arr]

    if prevTopX == nil then
      prevTopX = top_x
      prevBotX = bottom_x
    end

    if prevTopX - top_x < outlier_crit and bottom_x - prevBotX < outlier_crit then
      
      if bottom_x<x_bot_min then
        x_bot_min = bottom_x
      end
      
      if top_x<x_top_min then
        x_top_min = top_x
      end

      if y<y_min then
        y_min = y
      end

      table.insert(bot_x_arr, bottom_x )
      table.insert(top_x_arr, top_x)
      table.insert(y_arr, y)

      prevTopX = top_x
      prevBotX = bottom_x

    end
  end

  local botFirstAndLastQuarter = {}
  local count = 1
  for i=1, math.ceil(#bot_x_arr/4) do

    table.insert(botFirstAndLastQuarter, Point.create(count,bot_x_arr[i]))
    count = count+1
    table.insert(botFirstAndLastQuarter, Point.create(i+1,bot_x_arr[#bot_x_arr-i]))
    count = count+1
  end

  local y_bot_mean = Profile.createFromPoints(botFirstAndLastQuarter)
  y_bot_mean = y_bot_mean:getMean()
  y_bot_mean = math.floor(y_bot_mean)

  local topFirstAndLastQuarter = {}  
  local count = 1
  for i=1, math.ceil(#top_x_arr/4) do
    table.insert(topFirstAndLastQuarter, Point.create(count,top_x_arr[i]))
    count = count+1
    table.insert(topFirstAndLastQuarter, Point.create(i+1,top_x_arr[#top_x_arr-i]))
    count = count+1
  end

  local y_top_mean = Profile.createFromPoints(topFirstAndLastQuarter)
  y_top_mean = y_top_mean:getMean()
  y_top_mean = math.floor(y_top_mean)

  for i, y in ipairs(y_arr) do
    table.insert(bottomEdgePoints, Point.create(y-y_min, y_bot_mean + origin:getX(), bot_x_arr[i]-x_bot_min))
    table.insert(topEdgePoints, Point.create(y-y_min, y_top_mean + origin:getX(), top_x_arr[i]-x_top_min))
  end

  return bottomEdgePoints, topEdgePoints, x_bot_min,x_top_min
end


---@param image Image
---@param edgePoints any
local function getRegions(image, edgePoints)
  local regions = {}
  local x_offsets = {}
  local origins = {}

  local top_arr = edgePoints.top.x_points
  local top_y = edgePoints.top.y

  local mid_y = edgePoints.mid.y
  local mid_arr = edgePoints.mid.x_points

  local bot_arr = edgePoints.bot.x_points
  local bot_y = edgePoints.bot.y

  local top_y_arr = {}
  local bot_y_arr = {}

  for i=1,#top_arr do
    top_y_arr[i] = top_y
  end

  for i=1,#bot_arr do
    bot_y_arr[i] = bot_y
  end

  local top_points = Point.create(top_arr, top_y_arr)
  local top_straight_line_point = Point.create(bot_arr, top_y_arr)
  local bot_points = Point.create(bot_arr, bot_y_arr)
  local lines = Shape.createLine(top_points, bot_points)
  local straight_lines = Shape.createLineSegment(top_straight_line_point, bot_points)
  local angles = Shape.getIntersectionAngle(lines,straight_lines)
  local prev_distance_to_line = 999
  local i = 1

  while i<#lines do
    test_viewer1:clear()
    test_viewer1:addImage(image)
    test_viewer1:present()
    test_viewer2:clear()
    local mid_x = mid_arr[i+1]
    local center_midline_point = Point.create(mid_x, mid_y)
    local mid_center_2line_dist = center_midline_point:getDistanceToLine(lines[i])
     
    local center_x = mid_x - mid_center_2line_dist/2
    local center_point = Point.create(center_x, mid_y)
    local box_width = 3+mid_center_2line_dist/2

    if i ~= #lines and i ~= #lines -1 then
      local nextLine = lines[i+1]
      local nextNextLine = lines[i+2]

      local dist2nextNextLine = center_midline_point:getDistanceToLine(nextNextLine)/2
      if dist2nextNextLine < prev_distance_to_line then
        prev_distance_to_line = dist2nextNextLine
      end
      
      box_width = prev_distance_to_line/2 + mid_center_2line_dist/2
      test_viewer1:addPoint(center_midline_point, decoDot)
      test_viewer1:addShape(nextNextLine, decoFeature)
      test_viewer1:addShape(lines[i], decoTeach)
      
      test_viewer1:addShape(nextLine)
      test_viewer1:present()
    end
    local rect_height = Point.subtract(bot_points[i], top_points[i])
    test_viewer1:addPoint(center_point)
    test_viewer1:addShape(lines[1])
    test_viewer1:present()
    
    local region_rectangle = Shape.createRectangle(center_point, 2*box_width, rect_height:getY(), angles[i])

    local region = region_rectangle:toPixelRegion(image)
    local croppedRegion = image:cropRegion(region)
    local origin = croppedRegion:getOrigin()
    croppedRegion:setOrigin(Point.create(0,0))
    local rotCroppedRegion = croppedRegion:rotate(-angles[i])
    local width = rotCroppedRegion:getWidth()
    local height = rotCroppedRegion:getHeight()
    rotCroppedRegion = rotCroppedRegion:crop(0,5, rotCroppedRegion:getWidth(), rotCroppedRegion:getHeight()-10)
    test_viewer2:clear()
    test_viewer2:addImage(rotCroppedRegion)
    test_viewer2:present()
    local thresh_region = rotCroppedRegion:threshold(1,255)
    local region_pixels = thresh_region:toPoints2D(image)
    
    local y_arr = {}
    for _, regionPixel in pairs(region_pixels) do
      local y = regionPixel:getY()
      local x = regionPixel:getX()
      if y_arr[y] == nil then
        y_arr[y] = {x}
      else
        table.insert(y_arr[y], x)
      end

    end

    test_viewer1:addShape(region_rectangle, decoFeature)
    test_viewer1:present()

    local bottom_edge, top_edge, x_bot_min, x_top_min= extractRotatedEdgeFromRegion(image, y_arr, origin)

    table.insert(regions, bottom_edge)
    table.insert(x_offsets, x_bot_min)
    table.insert(origins, origin:getX()+x_bot_min)
    table.insert(regions, top_edge)
    table.insert(x_offsets, x_top_min)
    table.insert(origins, origin:getX()+x_top_min)
    i = i +2
  end
  return regions, angles
end

local function extractProfile(reg_pixels, angle)
  local profile = Profile.createFromPoints(reg_pixels)
  local y_min = profile:getMin()
  local x_min = math.abs(profile[1]:getX())
  return profile, x_min, y_min
end

---@param image Image
---@param region_pixels {}
local function createHeighmap(image, region_pixels, angles)
  local points3D = {} ---@type Point[]

  local y = 0

  for count, region in pairs(region_pixels) do
    for i, point in pairs(region) do
      table.insert(points3D, point)
    end
  end
  local pointcloud = PointCloud.createFromPoints(points3D)
    
  test_viewer3D:addPointCloud(pointcloud)
  test_viewer3D:present()

  local box = pointcloud:getBoundingBox()
  local pixel_size = {1,1,1} ---@type number[]

  local cast_cloud = pointcloud:toImage(box,pixel_size)
  test_viewer1:clear()
  test_viewer1:addHeightmap(cast_cloud)
  test_viewer1:present()
end

local function loadImages()
  --img = Image.load("resources/nove/Cam1_0_2.bmp" )
  local img = Image.load("resources/nove/Cam3_1.bmp" )
  img = img:crop(220,640,2215-255,1470-640)
  img:setOrigin(Point.create(0,0))
  test_viewer1:clear()
  test_viewer2:clear()
  test_viewer1:addImage(img)
  test_viewer1:present()
  return img
end

local function binarizeImage(orig_img)
  --local img_bin = orig_img:binarizeAdaptive(5,63, true,255)
  local img_bin = orig_img:binarize(26,140)
  local kernelPisSize = 3
  local img_dial = img_bin:morphology(2*kernelPisSize-1,"OPEN")
  --local img_erode = img_dial:morphology(9,"ERODE")
  --local img_bin_median = Image.median(img_bin:toImage(img), 5)
  local img_canny = img_dial:canny(255,5 )

  test_viewer1:clear()
  test_viewer1:addImage(img_canny)
  test_viewer1:present()
  return img_canny
 
end


local function main()
  -- write app code in local scope, using API
  local orig_img = loadImages()
  local img_canny = binarizeImage(orig_img)
  local edgePoints = extractEdgePoints(img_canny)
  local regions, angles = getRegions(img_canny, edgePoints)
  local heightmap = createHeighmap(img_canny, regions, angles)
  --local lines = getLines(img_canny, regions)
  --local profiles = getProfiles(img_canny, lines)
  --getLines()
end
Script.register("Engine.OnStarted", main)
-- serve API in global scope
