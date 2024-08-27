
   require("Decorations")

test_viewer1 = View.create("testDisplay1")
test_viewer2= View.create("testDisplay2")
test_viewer3D= View.create("testDisplay3D")

image_exposure = 6000

--- Get lines
---@param image Image
local function extractEdgePoints(image)

  local start_region = Point.create(250, 750)
  local mid_point = Point.create(250, 1095)
  local end_region = Point.create(2350, 1400)
  local max_dist = 50
  local y_profiles = {
    top={},
    mid={},
    bot={},
  }
  local profiles = {}
  local prof_count = 1
  local regions = {top=start_region:getY(), mid=mid_point:getY(),bot=end_region:getY() }

  for label, y in pairs(regions) do
      prof_count = 1
      prev_x = 1
      local x_profiles = {}
    for x = start_region:getX(),end_region:getX() do
      local pixel = image:getPixel(x,y,'RAW_COORDINATES')
      if pixel > 0 then
        if (prev_x ~= 1) and (x > prev_x + max_dist) then
          prof_count = prof_count + 3
        end
        x_profiles[prof_count] = x
        prof_count = prof_count + 1
        prev_x = x
      end
    end
    y_profiles[label] = {y=y, x_points = x_profiles}
  end

  return y_profiles
end



---@param image Image
local function getProfiles(image, profiles)
  local distProfiles ={}
  for x, profile_line in pairs(profiles) do
    --local polyline = Shape.toPolyline(profile_line,1)
    local distProfile, strengthProfile = image:extractEdgeProfile(profile_line, 20, 100)
    distProfiles[x] = {distProfile,strengthProfile}
  end
  
  test_viewer1:clear()
  test_viewer1:addProfile(distProfiles[254])
  test_viewer1:present()
  return distProfiles
end

local function getLines(image, regions)
  local lineSegments = {}

  local angle = math.rad(0)
  local shapeFitter = Image.ShapeFitter.create()
  test_viewer2:addImage(image)

  for x, region in pairs(regions) do
    local lineSeg = shapeFitter:fitLine(image,region, angle) 
    local linePoly = lineSeg:toPolyline(1)
    lineSegments[x] = linePoly
    test_viewer2:addShape(line,decoDot )
    test_viewer2:present()
  end

  return lineSegments
end

---comment
---@param regions Image.PixelRegion[]
local function getConnectedRegions(regions)
Image.PixelRegion.findConnected()
  for x, region in pairs(regions) do
    region:findConnected()
  end

end



---@param image Image
---@param edgePoints any
local function getRegions(image, edgePoints)

  local regions = {}
  local top_arr = edgePoints.top.x_points
  local top_y = edgePoints.top.y
  local mid_y = edgePoints.mid.y
  local mid_arr = edgePoints.mid.x_points
  local bot_arr = edgePoints.bot.x_points
  local bot_y = edgePoints.bot.y

  local top_y_arr = {}
  local mid_y_arr = {}
  local bot_y_arr = {}

  for i=1,#top_arr do
    top_y_arr[i] = top_y
    mid_y_arr[i] = mid_y
    bot_y_arr[i] = bot_y
  end

  local top_points = Point.create(top_arr, top_y_arr)
  local top_straight_line_point = Point.create(bot_arr, top_y_arr)

  local mid_points = Point.create(mid_arr, mid_y_arr)

  local bot_points = Point.create(bot_arr, bot_y_arr)

  local lines = Shape.createLine(top_points, bot_points)
  local straight_lines = Shape.createLineSegment(top_straight_line_point, bot_points)
  local angles = Shape.getIntersectionAngle(lines,straight_lines)
  local prev_distance_to_line = 999  
  for i=1,#lines do
    test_viewer1:clear()
    test_viewer1:addImage(image)
    test_viewer1:present()
    test_viewer2:clear()
    local mid_x = mid_arr[i]
    local center_midline_point = Point.create(mid_x, mid_y)
    local mid_center_2line_dist = center_midline_point:getDistanceToLine(lines[i])
     
    local center_x = mid_x - mid_center_2line_dist/2
    local center_point = Point.create(center_x, mid_y)
    local box_width = 3+mid_center_2line_dist/2

    if i ~= #lines then
      local nextLine = lines[i+1]
      local dist2Line = center_midline_point:getDistanceToLine(nextLine)
      if dist2Line < prev_distance_to_line then
        prev_distance_to_line = dist2Line
      end
      box_width = prev_distance_to_line/2 + mid_center_2line_dist/2
      test_viewer1:addPoint(center_midline_point)
      test_viewer1:addShape(nextLine)
      test_viewer1:present()

    end
    local rect_height = Point.subtract(bot_points[i], top_points[i])
    test_viewer1:addPoint(center_point)
    test_viewer1:addShape(lines[1])
    test_viewer1:present()
    
    local region_rectangle = Shape.createRectangle(center_point, 2*box_width, rect_height:getY(), angles[i])

    local region = region_rectangle:toPixelRegion(image)
    local thresh_region = image:threshold(1,255,region)
    local region_pixels = thresh_region:toPoints2D(image)
    
    test_viewer1:addShape(region_rectangle, decoFeature)
    test_viewer1:present()

    regions[i] = region_pixels
  end
  return regions, angles
end

local function extractProfile(reg_pixels, angle)
  local profile = Profile.createFromPoints(reg_pixels)
  local angle_90 = math.rad(90)
  local rotated = profile:rotate(angle_90-angle)
  local rotated_points = rotated:toPoints()
  local y_min = rotated:getMin()
  local x_min = math.abs(rotated_points[1]:getX())
  return profile, rotated_points, x_min, y_min
end

---@param image Image
---@param region_pixels {}
local function createHeighmap(image, region_pixels, angles)
  local points3D = {} ---@type Point[]

  local y = 0
  for i=1,#region_pixels-1 do
    -- TODO optimize
    local reg_pixels = region_pixels[i]
    local next_reg_pixels = region_pixels[i+1]
    local angle = angles[i]
    local next_angle = angles[i+1]
    

    local profile, rotated_points, x_min, y_min = extractProfile(reg_pixels, angle)
    test_viewer1:clear()
    test_viewer1:addProfile(profile)
    test_viewer1:present()
    local next_profile, next_rotated_points, next_x_min, next_y_min = extractProfile(next_reg_pixels, next_angle)

    test_viewer2:clear()
    test_viewer2:addProfile(next_profile)
    test_viewer2:present()


      y = y + (next_y_min - y_min)
    for i, rot_point in ipairs(rotated_points) do
      local z = math.abs(rot_point:getY()) - y_min
      local x = math.abs(rot_point:getX()) - x_min
      local new_point = Point.create(x,y,z)
      table.insert(points3D, new_point)
    end

    print(y)

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

---comment
---@param image Image
---@param regions Image.PixelRegion
local function findProfiles(image, regions)

  for i,region in ipairs(regions) do
    local test = 1
  end
end

local function loadImages()
  --img = Image.load("resources/nove/Cam1_0_2.bmp" )
  img = Image.load("resources/nove/Cam1_1.bmp" )
  --img = Image.load("resources/Cam1_0_Shutter" .. image_exposure .. ".bmp" )
  test_viewer1:clear()
  test_viewer2:clear()
  test_viewer1:addImage(img)
  test_viewer1:present()
end

local function binarizeImage()
  --local img_bin = img:binarizeAdaptive(7,45)
  local img_bin = img:binarize(20,255)
  local img_dial = img_bin:morphology(5,"OPEN")
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
  loadImages()
  local img_canny = binarizeImage()
  local edgePoints = extractEdgePoints(img_canny)
  local regions, angles = getRegions(img_canny, edgePoints)
  local heightmap = createHeighmap(img_canny, regions, angles)
  --local lines = getLines(img_canny, regions)
  --local profiles = getProfiles(img_canny, lines)
  --getLines()
  local profiles = findProfiles(img_canny, regions)
end
Script.register("Engine.OnStarted", main)
-- serve API in global scope
