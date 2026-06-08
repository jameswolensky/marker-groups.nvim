local function alpha(value)
  return value + 1
end

local function bravo(value)
  return value * 2
end

local function charlie(value)
  return alpha(value) + bravo(value)
end

return {
  alpha = alpha,
  bravo = bravo,
  charlie = charlie,
}
