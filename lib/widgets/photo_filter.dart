import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imageLib;
import 'package:path_provider/path_provider.dart';
import 'package:photofilters/filters/filters.dart';

class PhotoFilter extends StatelessWidget {
  final imageLib.Image image;
  final String filename;
  final Filter filter;
  final BoxFit fit;
  final Widget loader;

  PhotoFilter({
    required this.image,
    required this.filename,
    required this.filter,
    this.fit = BoxFit.fill,
    this.loader = const Center(child: CircularProgressIndicator()),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: compute(applyFilter, <String, dynamic>{
        "filter": filter,
        "image": image,
        "filename": filename,
      }),
      builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return loader;
          case ConnectionState.active:
          case ConnectionState.waiting:
            return loader;
          case ConnectionState.done:
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            return Image.memory(
              snapshot.data as dynamic,
              fit: fit,
            );
        }
      },
    );
  }
}

///The PhotoFilterSelector Widget for apply filter from a selected set of filters
class PhotoFilterSelector extends StatefulWidget {
  final Widget title;
  final Color appBarColor;
  final List<Filter> filters;
  final imageLib.Image image;
  final Widget loader;
  final BoxFit fit;
  final String filename;
  final bool circleShape;

  const PhotoFilterSelector({
    Key? key,
    required this.title,
    required this.filters,
    required this.image,
    this.appBarColor = Colors.blue,
    this.loader = const Center(child: CircularProgressIndicator()),
    this.fit = BoxFit.fill,
    required this.filename,
    this.circleShape = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => new _PhotoFilterSelectorState();
}

class _PhotoFilterSelectorState extends State<PhotoFilterSelector> {
  String? filename;
  Map<String, List<int>?> cachedFilters = {};
  Filter? _filter;
  imageLib.Image? image;
  late bool loading;

  @override
  void initState() {
    super.initState();
    loading = false;
    _filter = widget.filters[0];
    filename = widget.filename;
    image = widget.image;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
    binding.renderView.automaticSystemUiAdjustment = false;
    SystemChrome.setEnabledSystemUIOverlays([]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return SafeArea(
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: widget.title,
          backgroundColor: Colors.transparent,
          elevation: 0,
          brightness: Brightness.light,
          systemOverlayStyle: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent, // n
            systemNavigationBarIconBrightness:
                Brightness.light, // avigation bar color
            statusBarColor: Colors.transparent, //
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light, // status// bar color
          ),
          actions: <Widget>[
            loading
                ? Container()
                : IconButton(
                    icon: Icon(Icons.check),
                    onPressed: () async {
                      setState(() {
                        loading = true;
                      });
                      var imageFile = await saveFilteredImage();

                      Navigator.pop(context, {'image_filtered': imageFile});
                    },
                  )
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: loading
              ? widget.loader
              : Stack(
                  children: [
                    Positioned.fill(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        padding: EdgeInsets.all(0),
                        child: _buildFilteredImage(
                          _filter,
                          image,
                          filename,
                        ),
                      ),
                    ),
                    Positioned(
                      width: MediaQuery.of(context).size.width,
                      height: 200,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(00),
                              Colors.black.withAlpha(100),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      width: MediaQuery.of(context).size.width,
                      height: 300,
                      bottom: 0,
                      child: Container(
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withAlpha(100),
                                Colors.black.withAlpha(00),
                              ],
                            ),
                          ),
                          //color: Colors.black.withAlpha(60),
                          child: Padding(
                            padding: EdgeInsets.only(top: 20, bottom: 20),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.filters.length,
                              itemBuilder: (BuildContext context, int index) {
                                return InkWell(
                                  child: Container(
                                    alignment: Alignment.bottomCenter,
                                    padding: EdgeInsets.all(10.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Container(
                                          decoration: ShapeDecoration(shape: CircleBorder(side: BorderSide(width: 4,color: Colors.black.withAlpha(50)))),
                                          child:_buildFilterThumbnail(
                                              widget.filters[index],
                                              image,
                                              filename),
                                        ),

                                        SizedBox(
                                          height: 5.0,
                                        ),
                                        Text(
                                          widget.filters[index].name,
                                          style: TextStyle(color: Colors.white),
                                        )
                                      ],
                                    ),
                                  ),
                                  onTap: () => setState(() {
                                    _filter = widget.filters[index];
                                  }),
                                );
                              },
                            ),
                          )),
                    )
                  ],
                ),
        ),
      ),
    );
  }

  _buildFilterThumbnail(
      Filter filter, imageLib.Image? image, String? filename) {
    if (cachedFilters[filter.name] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return CircleAvatar(
                radius: 30.0,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    child: widget.loader,
                  )
                ),
                backgroundColor: Colors.white,
              );
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              cachedFilters[filter.name] = snapshot.data;
              return CircleAvatar(
                radius: 30.0,
                backgroundImage: MemoryImage(
                  snapshot.data as dynamic,
                  scale: .10
                ),
                backgroundColor: Colors.white,
              );
          }
          // unreachable
        },
      );
    } else {
      return CircleAvatar(
        radius: 30.0,
        backgroundImage: MemoryImage(
          cachedFilters[filter.name] as dynamic,scale: .10
        ),
        backgroundColor: Colors.white,
      );
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/filtered_${_filter?.name ?? "_"}_$filename');
  }

  Future<File> saveFilteredImage() async {
    var imageFile = await _localFile;
    await imageFile.writeAsBytes(cachedFilters[_filter?.name ?? "_"]!);
    return imageFile;
  }

  Widget _buildFilteredImage(
      Filter? filter, imageLib.Image? image, String? filename) {
    if (cachedFilters[filter?.name ?? "_"] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return widget.loader;
            case ConnectionState.active:
            case ConnectionState.waiting:
              return widget.loader;
            case ConnectionState.done:
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              cachedFilters[filter?.name ?? "_"] = snapshot.data;
              return widget.circleShape
                  ? SizedBox(
                      height: MediaQuery.of(context).size.width / 3,
                      width: MediaQuery.of(context).size.width / 3,
                      child: Center(
                        child: CircleAvatar(
                          radius: MediaQuery.of(context).size.width / 3,
                          backgroundImage: MemoryImage(
                            snapshot.data as dynamic,
                          ),
                        ),
                      ),
                    )
                  : Image.memory(
                      snapshot.data as dynamic,
                      fit: BoxFit.cover,
                    );
          }
          // unreachable
        },
      );
    } else {
      return widget.circleShape
          ? SizedBox(
              height: MediaQuery.of(context).size.width / 3,
              width: MediaQuery.of(context).size.width / 3,
              child: Center(
                child: CircleAvatar(
                  radius: MediaQuery.of(context).size.width / 3,
                  backgroundImage: MemoryImage(
                    cachedFilters[filter?.name ?? "_"] as dynamic,
                  ),
                ),
              ),
            )
          : Image.memory(
              cachedFilters[filter?.name ?? "_"] as dynamic,
              fit: widget.fit,
            );
    }
  }
}

///The global applyfilter function
FutureOr<List<int>> applyFilter(Map<String, dynamic> params) {
  Filter? filter = params["filter"];
  imageLib.Image image = params["image"];
  String filename = params["filename"];
  List<int> _bytes = image.getBytes();
  if (filter != null) {
    filter.apply(_bytes as dynamic, image.width, image.height);
  }
  imageLib.Image _image =
      imageLib.Image.fromBytes(image.width, image.height, _bytes);
  _bytes = imageLib.encodeNamedImage(_image, filename)!;

  return _bytes;
}

///The global buildThumbnail function
FutureOr<List<int>> buildThumbnail(Map<String, dynamic> params) {
  int? width = params["width"];
  params["image"] = imageLib.copyResize(params["image"], width: width);
  return applyFilter(params);
}
