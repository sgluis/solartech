@IsTest
public class WeatherApiMocks {
    // —— casos generales ——
    public class BadWeatherMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type','application/json');
            res.setBody(
                '{"list":[{"main":{"temp":15},"wind":{"speed":12.5},' +
                '"weather":[{"id":200,"main":"Thunderstorm"}]}]}'
            );
            return res;
        }
    }
    public class GoodWeatherMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type','application/json');
            res.setBody(
                '{"list":[{"main":{"temp":22},"wind":{"speed":3.2},' +
                '"weather":[{"id":800,"main":"Clear"}]}]}'
            );
            return res;
        }
    }
    public class ApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error interno');
            return res;
        }
    }

    // —— edge cases para viento ——  
    public class WindAboveMock implements HttpCalloutMock {
        // ahora >10.0
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody(
                '{"list":[{"main":{"temp":20},"wind":{"speed":10.1},' +
                '"weather":[{"id":800}]}]}'
            );
            return r;
        }
    }
    public class WindBoundaryMock implements HttpCalloutMock {
        // exactamente 10.0
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody(
                '{"list":[{"main":{"temp":20},"wind":{"speed":10.0},' +
                '"weather":[{"id":800}]}]}'
            );
            return r;
        }
    }
    public class WeatherId200Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type','application/json');
            r.setBody(
                '{"list":[{"main":{"temp":18},"wind":{"speed":5.0},' +
                '"weather":[{"id":200}]}]}'
            );
            return r;
        }
    }
}