import '../models/clock_task_model.dart';

class NextTaskService {
  static ClockTaskModel getNextTask(
    List<ClockTaskModel> tasks,
  ) {
    // TYMCZASOWO ZWRACA DRUGIE ZADANIE
    // PÓŹNIEJ BĘDZIE PRAWDZIWA LOGIKA CZASU

    return tasks[1];
  }
}