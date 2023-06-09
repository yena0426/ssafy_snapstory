import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snapstory/views/home/home_view.dart';
import 'package:snapstory/views/home/make_story_view.dart';
import 'package:snapstory/views/main_view.dart';
import 'package:http/http.dart' as http;
import 'package:snapstory/views/my_library/my_library_view.dart';
import 'package:network_to_file_image/network_to_file_image.dart';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class CompleteStory extends StatefulWidget {
  const CompleteStory({Key? key, required this.id}) : super(key: key);

  final int id;

  @override
  State<CompleteStory> createState() => _CompleteStoryState();
}

class _CompleteStoryState extends State<CompleteStory> {
  late FlutterTts flutterTts;
  late FairyTale ft;
  late bool isEng = true;
  late String wordKor;

  final searchController = TextEditingController();
  late TranslateLanguage sourceLanguage = TranslateLanguage.english;
  late TranslateLanguage targetLanguage = TranslateLanguage.korean;
  late final onDeviceTranslator = OnDeviceTranslator(
      sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);

  String translate = '';
  bool isSearching = false;
  bool counterShow = false;
  bool isPlaying = false;
  final FocusNode _focusNode = FocusNode();

  Future<int> makeSound({required String text}) async {
    isEng ? flutterTts.setLanguage("en-US") : flutterTts.setLanguage("ko-KR");

    return await flutterTts.speak(text);
  }

  // 스토리 정보 받아오기
  Future<FairyTale> getStory() async {
    // 토큰 뽑기
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();

    // 동화 정보 불러오기
    // 이미지 없는 동화 먼저 저장
    final response = await http.get(
      Uri.parse("https://j8a401.p.ssafy.io/api/v1/ai-tales/${widget.id}"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );

    Map<String, dynamic> result = jsonDecode(utf8.decode(response.bodyBytes));
    wordKor = result["result"]["wordKor"];

    return FairyTale(
        result["result"]["contentEng"],
        result["result"]["contentKor"],
        result["result"]["image"],
        result["result"]["wordEng"]);
  }

  @override
  void initState() {
    flutterTts = FlutterTts();
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.4); //speed of speech
    flutterTts.setVolume(0.7); //volume of speech
    flutterTts.setPitch(1.33);

    super.initState();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  final modelManager = OnDeviceTranslatorModelManager();

  // 검색 모달창
  searchModal() async {
    return showDialog(
        barrierColor: Colors.transparent,
        context: context,
        builder: (context) {
          // 모달 켰을 때, 데이터 초기화
          searchController.text = '';
          translate = '';
          counterShow = false;

          return AlertDialog(
            alignment: Alignment.bottomCenter,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.all(0),
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return Container(
                padding:
                    EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                height: MediaQuery.of(context).size.height * 0.25,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xffffb628),
                    width: 5,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    SafeArea(
                      // 검색창
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.08,
                        child: TextField(
                          // 글자수 30자로 제한
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          maxLength: 30,
                          controller: searchController,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize:
                                  MediaQuery.of(context).textScaleFactor * 24),
                          cursorColor: Colors.white,
                          autofocus: true,
                          // 글자수가 30보다 크면 counterText 뜨게
                          onChanged: (text) {
                            if (text.length >= 30) {
                              setState(() {
                                counterShow = true;
                              });
                            } else {
                              setState(() {
                                counterShow = false;
                              });
                            }
                          },
                          decoration: InputDecoration(
                              counterText:
                                  (counterShow) ? '30자 이내로 입력해주세요' : '',
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 15),
                              filled: true,
                              // 검색 버튼
                              suffixIcon: IconButton(
                                  padding: const EdgeInsets.all(0),
                                  onPressed: () async {
                                    setState(() {
                                      isSearching = true;
                                    });
                                    String result = await onDeviceTranslator
                                        .translateText(searchController.text);
                                    setState(() {
                                      translate = result;
                                      isSearching = false;
                                    });
                                  },
                                  icon: const Icon(Icons.search_rounded,
                                      color: Colors.white, size: 40)),
                              fillColor: const Color(0xffffb628),
                              border: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(30)))),
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.search,
                          // 엔터키 눌렀을 때
                          onSubmitted: (value) async {
                            _focusNode.requestFocus();
                            searchController.text = value;
                            searchController.selection =
                                TextSelection.fromPosition(TextPosition(
                                    offset: searchController.text.length));
                            setState(() {
                              isSearching = true;
                            });
                            String result = await onDeviceTranslator
                                .translateText(searchController.text);
                            setState(() {
                              translate = result;
                              isSearching = false;
                            });
                          },
                        ),
                      ),
                    ),
                    // 결과 나오는 부분
                    Container(
                        alignment: Alignment.center,
                        child: (isSearching)
                            ? const CircularProgressIndicator()
                            : Text(
                                translate,
                                style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).textScaleFactor *
                                            30),
                              ))
                  ],
                ),
              );
            }),
          );
        });
  }

  // 듣기 or 정지
  playingStop(text) async {
    // 듣는 중이면 tts stop & isPlaying false
    if (isPlaying) {
      await flutterTts.stop();
      setState(() {
        isPlaying = false;
      });
    } else {
      // 아니면 tts 실행하는 동안 isPlaying true
      setState(() {
        isPlaying = true;
      });
      await makeSound(text: text);

      flutterTts.setCompletionHandler(() {
        setState(() {
          isPlaying = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              Container(
                height: MediaQuery.of(context).size.height,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: AssetImage('assets/main/bg-main.png'), // 배경 이미지
                  ),
                ),
                child: SingleChildScrollView(
                  child: Center(
                    child: FutureBuilder(
                        future: getStory(),
                        builder:
                            (BuildContext context, AsyncSnapshot snapshot) {
                          //error가 발생하게 될 경우 반환하게 되는 부분
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(fontSize: 50),
                              ),
                            );
                          }
                          //해당 부분은 data를 아직 받아 오지 못했을때 실행되는 부분을 의미한다.
                          else if (snapshot.hasData == false) {
                            return const CircularProgressIndicator();
                          }
                          // 데이터를 정상적으로 받아오게 되면 다음 부분을 실행하게 되는 것이다.
                          else {
                            ft = snapshot.data! as FairyTale;
                            return Center(
                                child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.15,
                                    ),
                                    Image(
                                        image: const AssetImage(
                                            "assets/aiTale/box-aitale-title.png"),
                                        width:
                                            MediaQuery.of(context).size.width),
                                    Padding(
                                      padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.02),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            isEng ? "Story about " : wordKor,
                                            style: isEng
                                                ? TextStyle(
                                                    fontSize: MediaQuery.of(
                                                                context)
                                                            .textScaleFactor *
                                                        23)
                                                : TextStyle(
                                                    fontSize: MediaQuery.of(
                                                                context)
                                                            .textScaleFactor *
                                                        23,
                                                    color: Colors.red),
                                          ),
                                          Text(
                                            isEng ? ft.wordEng : " 이야기",
                                            style: isEng
                                                ? TextStyle(
                                                    fontSize: MediaQuery.of(
                                                                context)
                                                            .textScaleFactor *
                                                        23,
                                                    color: Colors.red)
                                                : TextStyle(
                                                    fontSize: MediaQuery.of(
                                                                context)
                                                            .textScaleFactor *
                                                        23),
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        width: 4, color: Colors.amber),
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(40.0)),
                                    shape: BoxShape.rectangle,
                                  ),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(40),
                                      child: Image.network(
                                        ft.image,
                                        width: 300,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 300,
                                            width: 300,
                                            padding: EdgeInsets.all(10),
                                            child: Image.asset(
                                              'assets/snappy_crying.png',
                                              fit: BoxFit.contain,
                                            ),
                                          );
                                        },
                                      )),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    isEng = !isEng;
                                  }),
                                  child: Container(
                                      margin: EdgeInsets.fromLTRB(
                                          MediaQuery.of(context).size.width *
                                              0.08,
                                          MediaQuery.of(context).size.height *
                                              0.02,
                                          MediaQuery.of(context).size.width *
                                              0.08,
                                          MediaQuery.of(context).size.width *
                                              0.4),
                                      child: isEng
                                          ? Text(ft.contentEng.split("\"")[1].split("\n")[2],
                                              style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .textScaleFactor *
                                                          25),
                                              textAlign: TextAlign.justify)
                                          : Text(ft.contentKor.split("\n")[2],
                                              style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context).textScaleFactor * 25),
                                              textAlign: TextAlign.justify)),
                                ),
                              ],
                            ));
                          }
                        }),
                  ),
                ),
              ),

              //하단바
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  // color: Colors.transparent,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * 0.1,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32)),
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: AssetImage('assets/main/bg-bar.png'),
                      // 배경 이미지
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.03,
                left: MediaQuery.of(context).size.width * 0.05,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.3,
                        height: MediaQuery.of(context).size.width * 0.3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: (isPlaying)
                                // 듣는 중이면 일시정지, 아니면 듣기
                                ? AssetImage(
                                    'assets/aiTale/btn-aitale-stop.png')
                                : AssetImage(
                                    'assets/aiTale/btn-aitale-sound.png'),
                          ),
                        ),
                      ),
                      onTap: () {
                        String text = isEng
                            ? ft.contentEng
                                .split("\"")[1]
                                .split("\n")[2] // "" 빼기
                            : ft.contentKor;
                        playingStop(text);
                      },
                    ),
                    GestureDetector(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.3,
                        height: MediaQuery.of(context).size.width * 0.3,
                        // margin: const EdgeInsets.fromLTRB(0, 0, 0, 70),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          image: const DecorationImage(
                            fit: BoxFit.cover,
                            image: AssetImage(
                                'assets/aiTale/btn-aitale-search.png'),
                          ),
                        ),
                      ),
                      onTap: () {
                        // 검색창 띄우기
                        searchModal();
                      },
                    ),
                    GestureDetector(
                      onTap: () => {
                        flutterTts.stop(),
                        Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const MainView(selectedPage: 1)),
                            (route) => false)
                        // Navigator.of(context).pop()
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.3,
                        height: MediaQuery.of(context).size.width * 0.3,
                        // margin:
                        // const EdgeInsets.fromLTRB(0, 0, 0, 70),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          image: const DecorationImage(
                            fit: BoxFit.cover,
                            image: AssetImage(
                                'assets/aiTale/btn-aitale-library.png'),
                            // 배경 이미지
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ));
  }
}
