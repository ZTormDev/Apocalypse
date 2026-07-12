--!strict
-- ReplicatedStorage.Shared.ModelBounds
-- Computes an axis-aligned bounding box (AABB) for a Model by scanning every BasePart's actual
-- world-space corners (not just its PrimaryPart), so UI anchored to the model -- health bars,
-- name tags -- can be centered on its true visual extent regardless of which part is the
-- PrimaryPart or how the model's parts are shaped/rotated.
local CORNER_SIGNS = {
	Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
}

local ModelBounds = {}

-- Returns the world-space AABB of `model` as (center: Vector3, size: Vector3), computed from
-- every descendant BasePart's 8 corners (so rotated parts are accounted for correctly).
-- Falls back to a 1x1x1 box at the model's pivot if it has no BaseParts.
function ModelBounds.getAABB(model: PVInstance): (Vector3, Vector3)
	local min: Vector3? = nil
	local max: Vector3? = nil

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local cf = part.CFrame
			local half = part.Size / 2
			for _, signs in ipairs(CORNER_SIGNS) do
				local pos = (cf * CFrame.new(half.X * signs.X, half.Y * signs.Y, half.Z * signs.Z)).Position
				if not min or not max then
					min, max = pos, pos
				else
					min = Vector3.new(math.min(min.X, pos.X), math.min(min.Y, pos.Y), math.min(min.Z, pos.Z))
					max = Vector3.new(math.max(max.X, pos.X), math.max(max.Y, pos.Y), math.max(max.Z, pos.Z))
				end
			end
		end
	end

	if not min or not max then
		local pivot = model:GetPivot()
		return pivot.Position, Vector3.new(1, 1, 1)
	end

	local center = (min + max) / 2
	local size = max - min
	return center, size
end

-- Returns a world-space point centered above the model's AABB, `padding` studs above its top.
-- Handy for BillboardGui StudsOffsetWorldSpace so the UI stays centered/on top regardless of
-- the shape of the model or which part it's adorned to.
function ModelBounds.getTopCenter(model: PVInstance, padding: number?): Vector3
	local center, size = ModelBounds.getAABB(model)
	return center + Vector3.new(0, size.Y / 2 + (padding or 0), 0)
end

return ModelBounds
