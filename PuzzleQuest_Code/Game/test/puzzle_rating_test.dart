import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/models.dart';

void main() {
  group('Q05-T / Q05-X level star policy', () {
    test('no star for failure or timeout', () {
      expect(PuzzleRating.calculate(activeSeconds:360,limit:360,three:150,two:270,aids:0,completed:true),0);
      expect(PuzzleRating.calculate(activeSeconds:100,limit:360,three:150,two:270,aids:0,completed:false),0);
    });
    test('three stars require no assistance and three-star time', () {
      expect(PuzzleRating.calculate(activeSeconds:150,limit:360,three:150,two:270,aids:0,completed:true),3);
      expect(PuzzleRating.calculate(activeSeconds:151,limit:360,three:150,two:270,aids:0,completed:true),2);
      expect(PuzzleRating.calculate(activeSeconds:149,limit:360,three:150,two:270,aids:1,completed:true),2);
    });
    test('more than one aid caps rating at one', () {
      expect(PuzzleRating.calculate(activeSeconds:10,limit:360,three:150,two:270,aids:2,completed:true),1);
      expect(PuzzleRating.calculate(activeSeconds:271,limit:360,three:150,two:270,aids:0,completed:true),1);
    });
    test('score is capped and has one penalty per help', () {
      expect(PuzzleRating.score(activeSeconds:0,limit:360,aids:0,completed:true),1500);
      expect(PuzzleRating.score(activeSeconds:0,limit:360,aids:1,completed:true),1400);
      expect(PuzzleRating.score(activeSeconds:360,limit:360,aids:0,completed:true),0);
      expect(PuzzleRating.score(activeSeconds:20,limit:360,aids:0,completed:false),0);
    });
  });
}
