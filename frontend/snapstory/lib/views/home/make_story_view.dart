import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 필요한 것
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:openai_client/openai_client.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snapstory/services/ar_ai_service.dart';
import 'dart:io' as io;

import 'complete_story_view.dart';

const apiKey = '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';
const apiUrl = 'https://api.openai.com/v1/completions';

// dalle가 만든 이미지 리스트
final List<String> imgList = [];

// complete_story_view로 넘어갈 변수 2개
String story = ""; // chatGpt가 만든 스토리
String selectedImg = ""; // 선택한 이미지
late int aiTaleId;

// 동화 클래스
class FairyTale {
  final String contentEng;
  final String contentKor;
  final String image;
  final String wordEng;

  const FairyTale(this.contentEng, this.contentKor, this.image, this.wordEng);
}

//
final List<Widget> imageSliders = imgList
    .map((item) => Container(
          margin: const EdgeInsets.all(5.0),
          child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
              child: Stack(
                children: <Widget>[
                  Image.network(item, fit: BoxFit.cover, width: 1000.0),
                  Positioned(
                    bottom: 0.0,
                    left: 0.0,
                    right: 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 20.0),
                    ),
                  ),
                ],
              )),
        ))
    .toList();

Future<void> saveImg() async {
  String imageURL =
      "https://blog.kakaocdn.net/dn/VIxFi/btqZqqf3QFS/n2otuLtHQo8TQVOwMAmmbk/img.png";

  try {
    // generate random number.
    var rng = new Random();
// get temporary directory of device.
    io.Directory tempDir = await getTemporaryDirectory();
// get temporary path from temporary directory.
    String tempPath = tempDir.path;
// create a new file in temporary path with random file name.
    io.File file =
        io.File('$tempPath' + (rng.nextInt(100)).toString() + '.png');
// call http.get method and pass imageUrl into it to get response.
    http.Response response = await http.get(imageURL as Uri);
// write bodyBytes received in response to file.
    await file.writeAsBytes(response.bodyBytes);
// now return the file which is created with random name in
// temporary directory and image bytes from response is written to // that file.
  } catch (e) {
    print(e);
  }
}

class MakeStory extends StatefulWidget {
  const MakeStory({Key? key, required this.word}) : super(key: key);

  final String word;

  @override
  State<MakeStory> createState() => _MakeStoryState();
}

class _MakeStoryState extends State<MakeStory> {
  late Future myFuture;
  late ARAIService _araiService;

  @override
  void initState() {
    _araiService = ARAIService();
    super.initState();
  }

  // dall-e 사용하기
  Future<String> askToDalle(String imgStr) async {
    // Create a new client.
    final client = OpenAIClient(
      configuration: const OpenAIConfiguration(
        apiKey: apiKey,
      ),
    );

    // Create an image.
    final image = await client.images
        .create(
          prompt: 'cute illust of a group of $imgStr',
          n: 4, // 원하는 이미지 개수
        )
        .data;

    for (int i = 0; i < 4; i++) {
      // 이미지 리스트에 추가
      imgList
          .add(image.data.toList().elementAt(i).props.elementAt(0).toString());
    }

    print(imgList.toString());

    return (image.data
        .toList()
        .elementAt(1)
        .props
        .elementAt(0)
        .toString()); // 첫번째 elementAt에 들어가는 숫자가 달리가 불러오는 이미지 인덱스
  }

  // GPT 사용하기 (동화텍스트와 동화 이미지 경로를 반환)
  Future<List<String>> askToGpt() async {
    String obj = widget.word; // 인식한 사물 이름 넣기
    String data =
        await _araiService.generateStoryandImage(obj); // 동화와 이미지 문장 만들기

    List<String> str = data.split("Image:");

    String fairytale = str[0]; // 동화 저장
    story = fairytale;
    String imgStr = str[1]; // 달리한테 보내줄 이미지 설명 저장
    String fairytaleKor =
        await _araiService.translateText(fairytale); // 동화 번역하기
    String? imgPath = await askToDalle(imgStr); // 달리로 이미지 경로 생성

    // 확인
    print("동화:" + fairytale);
    print("동화 해석:" + fairytaleKor);
    print("이미지 설명:" + imgStr);
    // print("이미지 경로:" + imgPath);

    // 동화 객체 만들기
    FairyTale ft = FairyTale(fairytale, fairytaleKor, "", widget.word);

    // 토큰 뽑기
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();

    // 이미지 없는 동화 먼저 저장
    final response = await http.post(
      Uri.parse("https://j8a401.p.ssafy.io/api/v1/ai-tales"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        "contentEng": ft.contentEng,
        "contentKor": ft.contentKor,
        "image": ft.image,
        "word": ft.wordEng
      }),
    );

    print(response.body.toString());
    aiTaleId = jsonDecode(utf8.decode(response.bodyBytes))['result']['aiTaleId'] as int;// 결과 확인하고 ai tale id 뽑아쓰기

    return [fairytale, imgPath]; // 동화를 반환
  }

  Future<bool> putImage(String url) async {
    // 토큰 뽑기
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();

    final response = await http.put(
      Uri.parse("https://j8a401.p.ssafy.io/api/v1/ai-tales/$aiTaleId"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        "image": url,
      }),
    );

    print("put 요청 결과:" + response.body.toString());

    return true;
  }

  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // borderRadius: BorderRadius.circular(23),
        // color: const Color(0xffffdb1f),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage('assets/bg/bg-main3.png'), // 배경 이미지
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
          body: Center(
        child: FutureBuilder(
            future: askToGpt(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            "멋진 동화",
                            style: TextStyle(fontSize: 30, color: Colors.amber),
                          ),
                          Text(
                            "가",
                            style: TextStyle(fontSize: 30),
                          ),

                        ],
                      ),
                      Text(
                        "완성되었습니다!",
                        style: TextStyle(fontSize: 30),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.03,
                      ),
                      const Text("원하는 동화 표지를 선택해주세요.", style: TextStyle(fontSize: 24)),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.03,
                      ),
                      CarouselSlider(
                        options: CarouselOptions(
                            aspectRatio: 2.0,
                            enlargeCenterPage: true,
                            enableInfiniteScroll: false,
                            initialPage: 0,
                            autoPlay: false,
                            onPageChanged: (index, reason) {
                              // setState(() {
                              _current = index;
                              // });
                            }),
                        items: imageSliders,
                      ),

                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.03,
                      ),

                      // Image.network(snapshot.data[1]),
                      TextButton(
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                              Colors.amber),
                          foregroundColor:
                          MaterialStateProperty.all(Colors.white),
                        ),
                        onPressed: () async {
                          print(_current);
                          selectedImg = imgList[_current];
                          await putImage(selectedImg); // put
                          saveImg();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompleteStory(id: aiTaleId),
                            ),
                          );

                        },
                          child: const Text("이 표지로 결정", style: TextStyle(color: Colors.white),)
                      ),
                      // OutlinedButton(
                      //     onPressed: () async {
                      //       // 표지 선택 누르면 put 요청 보냄 (만들어진 동화에 이미지 추가)
                      //
                      //       print(_current);
                      //       selectedImg = imgList[_current];
                      //       await putImage(selectedImg); // put
                      //       saveImg();
                      //       Navigator.push(
                      //         context,
                      //         MaterialPageRoute(
                      //           builder: (context) => CompleteStory(id: aiTaleId),
                      //         ),
                      //       );
                      //     },
                      //     child: const Text("이 표지로 결정", style: TextStyle(color: Colors.white),))
                    ],
                  ),
                );
              }
            }),
      )),
    );
  }
}
