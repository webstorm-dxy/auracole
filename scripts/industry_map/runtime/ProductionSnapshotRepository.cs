using Godot;
using Auracole.IndustryMap.Data;

namespace Auracole.IndustryMap.Runtime;

/// <summary>
/// 负责生产快照文件的 JSON 读写，避免场景管理器直接处理磁盘格式。
/// </summary>
public sealed class ProductionSnapshotRepository
{
	private readonly string _snapshotPath;

	public ProductionSnapshotRepository(string snapshotPath)
	{
		_snapshotPath = snapshotPath;
	}

	public void Save(ProductionSnapshotFile snapshotFile)
	{
		string json = Json.Stringify(ProductionSerialization.SerializeSnapshotFile(snapshotFile), "\t", true);
		using FileAccess file = FileAccess.Open(_snapshotPath, FileAccess.ModeFlags.Write);
		file.StoreString(json);
	}

	public ProductionSnapshotFile? TryLoad(out bool fileMissing, out bool parseFailed)
	{
		fileMissing = false;
		parseFailed = false;

		if (!FileAccess.FileExists(_snapshotPath))
		{
			fileMissing = true;
			return null;
		}

		using FileAccess file = FileAccess.Open(_snapshotPath, FileAccess.ModeFlags.Read);
		string jsonText = file.GetAsText();
		Variant parsed = Json.ParseString(jsonText);
		if (parsed.VariantType != Variant.Type.Dictionary)
		{
			parseFailed = true;
			return null;
		}

		return ProductionSerialization.DeserializeSnapshotFile(parsed.AsGodotDictionary());
	}
}
