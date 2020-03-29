class AnalysisError extends Error {

  final String message;
  final dynamic causedBy;

  AnalysisError(this.message, {this.causedBy});

  @override
  String toString() {
    var stringRepresentation = "";

    if (this.message != null) {
      stringRepresentation += this.message;
    }

    dynamic causedBy = this.causedBy;
    if (causedBy != null) {
      stringRepresentation += "Caused by: ${causedBy.toString()}\n";
      if (causedBy is Error) {
        stringRepresentation += causedBy.stackTrace.toString();
      }
    }

    return stringRepresentation;
  }
}