defmodule SM.ImageProcessingTest do
  use ExUnit.Case, async: true

  @exif_fixture Path.join(__DIR__, "../fixtures/exif_sample.jpg")
  @tmp_dir Path.join(System.tmp_dir!(), "safarimanager_image_processing_test")

  setup do
    File.mkdir_p!(@tmp_dir)

    on_exit(fn ->
      File.rm_rf(@tmp_dir)
    end)

    :ok
  end

  test "get_metadata/1 returns dimensions and EXIF for JPEG with metadata" do
    assert {:ok, width, height, meta} = SM.ImageProcessing.get_metadata(@exif_fixture)
    assert width > 0
    assert height > 0
    assert is_map(meta)
    assert Map.has_key?(meta, :gps)
    assert meta["DateTime"] == "2016-05-04 03:02:01"
  end

  test "save_thumbnail/4 writes a filled thumbnail at requested dimensions" do
    out = Path.join(@tmp_dir, "thumb.jpg")
    assert :ok = SM.ImageProcessing.save_thumbnail(@exif_fixture, 80, 80, out)
    assert File.exists?(out)
    {:ok, bin} = File.read(out)
    assert {:ok, %{width: 80, height: 80}} = ExImageResizer.info(bin)
  end
end
