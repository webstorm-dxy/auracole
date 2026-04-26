using System;
using System.Collections.Generic;
using System.Linq;

namespace Auracole.IndustryMap.Data;

/// <summary>
/// 提供离线推演中共用的数值工具和缓冲区辅助方法。
/// </summary>
public static class ProductionMath
{
	/// <summary>
	/// 浮点数比较容差。
	/// </summary>
	public const float Epsilon = 1e-4f;

	/// <summary>
	/// 离线推演在该阈值以下视为可直接停止。
	/// </summary>
	public const float StopThreshold = 1e-3f;
	private const int UnlimitedCapacity = int.MaxValue / 4;

	/// <summary>
	/// 比较两个浮点数是否在容差范围内近似相等。
	/// </summary>
	public static bool NearlyEqual(float a, float b)
	{
		return MathF.Abs(a - b) <= Epsilon;
	}

	/// <summary>
	/// 判断浮点数是否近似为零。
	/// </summary>
	public static bool IsNearlyZero(float value)
	{
		return MathF.Abs(value) <= Epsilon;
	}

	/// <summary>
	/// 获取某种物品的容量上限；未配置时视为无限容量。
	/// </summary>
	public static int GetCapacity(Dictionary<string, int> capacityMap, string itemId)
	{
		return capacityMap.TryGetValue(itemId, out int capacity) ? capacity : UnlimitedCapacity;
	}

	/// <summary>
	/// 获取缓冲区中的物品数量；不存在时返回 0。
	/// </summary>
	public static int GetAmount(Dictionary<string, int> buffer, string itemId)
	{
		return buffer.TryGetValue(itemId, out int amount) ? amount : 0;
	}

	/// <summary>
	/// 设置缓冲区中某种物品的数量；小于等于 0 时直接移除键。
	/// </summary>
	public static void SetAmount(Dictionary<string, int> buffer, string itemId, int amount)
	{
		if (amount <= 0)
		{
			buffer.Remove(itemId);
			return;
		}

		buffer[itemId] = amount;
	}

	/// <summary>
	/// 向缓冲区写入指定数量的物品，并遵守容量限制，返回实际接收量。
	/// </summary>
	public static int AddWithCapacity(Dictionary<string, int> buffer, Dictionary<string, int> capacityMap, string itemId, int amount)
	{
		if (amount <= 0)
		{
			return 0;
		}

		int current = GetAmount(buffer, itemId);
		int capacity = GetCapacity(capacityMap, itemId);
		int accepted = Math.Min(amount, Math.Max(0, capacity - current));
		if (accepted > 0)
		{
			buffer[itemId] = current + accepted;
		}

		return accepted;
	}

	/// <summary>
	/// 从缓冲区中精确扣除指定数量的物品。
	/// </summary>
	public static void RemoveExact(Dictionary<string, int> buffer, string itemId, int amount)
	{
		if (amount <= 0)
		{
			return;
		}

		int current = GetAmount(buffer, itemId);
		SetAmount(buffer, itemId, Math.Max(0, current - amount));
	}

	/// <summary>
	/// 判断缓冲区是否满足一组输入需求。
	/// </summary>
	public static bool HasRequiredItems(Dictionary<string, int> buffer, IReadOnlyDictionary<string, int> requirement)
	{
		foreach (KeyValuePair<string, int> pair in requirement)
		{
			if (GetAmount(buffer, pair.Key) < pair.Value)
			{
				return false;
			}
		}

		return true;
	}

	/// <summary>
	/// 将库存字典格式化为适合 UI 日志展示的文本。
	/// </summary>
	public static string FormatInventory(IReadOnlyDictionary<string, int> inventory)
	{
		if (inventory.Count == 0)
		{
			return "0";
		}

		return string.Join(", ", inventory.OrderBy(pair => pair.Key, StringComparer.Ordinal)
			.Select(pair => $"{pair.Key} x{pair.Value}"));
	}
}
