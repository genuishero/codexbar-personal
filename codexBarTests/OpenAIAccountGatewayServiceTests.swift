import Foundation
import XCTest

final class OpenAIAccountGatewayServiceTests: CodexBarTestCase {
    func testResponsesProbeGETBuildsWebSocketHandshakeWhenHeadersAndAccountExist() async throws {
        let service = OpenAIAccountGatewayService(
            urlSession: self.makeMockSession(),
            runtimeConfiguration: .init(
                host: "127.0.0.1",
                port: 1456,
                upstreamResponsesURL: URL(string: "https://example.invalid/v1/responses")!
            )
        )

        let account = TokenAccount(
            email: "alpha@example.com",
            accountId: "acct-alpha",
            openAIAccountId: "openai-alpha",
            accessToken: "token-alpha",
            refreshToken: "refresh-alpha",
            idToken: "id-alpha",
            planType: "plus",
            primaryUsedPercent: 10,
            secondaryUsedPercent: 10
        )
        service.updateState(
            accounts: [account],
            quotaSortSettings: .init(),
            accountUsageMode: .aggregateGateway
        )

        let request = try XCTUnwrap(
            service.parseRequestForTesting(
                from: self.rawRequest(
                    lines: [
                        "GET /v1/responses HTTP/1.1",
                        "Host: 127.0.0.1:1456",
                        "Connection: Upgrade",
                        "Upgrade: websocket",
                        "Sec-WebSocket-Version: 13",
                        "Sec-WebSocket-Key: dGVzdC1jb2RleGJhcg==",
                    ]
                )
            )
        )

        let response = service.webSocketUpgradeProbeForTesting(request: request)

        XCTAssertEqual(response.statusCode, 101)
        XCTAssertEqual(
            response.headers["Sec-WebSocket-Accept"],
            "jbsNjU5oGfarrt3XvjT/Dv7jeRU="
        )
        XCTAssertEqual(response.headers["Upgrade"], "websocket")
        XCTAssertEqual(response.headers["Connection"], "Upgrade")
        XCTAssertTrue(response.body.isEmpty)
    }

    func testResponsesPOSTFailoverRebindsStickySessionAndRewritesHeaders() async throws {
        let service = OpenAIAccountGatewayService(
            urlSession: self.makeMockSession(),
            runtimeConfiguration: .init(
                host: "127.0.0.1",
                port: 1456,
                upstreamResponsesURL: URL(string: "https://example.invalid/v1/responses")!
            )
        )

        let primary = TokenAccount(
            email: "alpha@example.com",
            accountId: "acct-alpha",
            openAIAccountId: "openai-alpha",
            accessToken: "token-alpha",
            refreshToken: "refresh-alpha",
            idToken: "id-alpha",
            planType: "plus",
            primaryUsedPercent: 10,
            secondaryUsedPercent: 10
        )
        let secondary = TokenAccount(
            email: "beta@example.com",
            accountId: "acct-beta",
            openAIAccountId: "openai-beta",
            accessToken: "token-beta",
            refreshToken: "refresh-beta",
            idToken: "id-beta",
            planType: "free",
            primaryUsedPercent: 10,
            secondaryUsedPercent: 10
        )

        service.updateState(
            accounts: [primary, secondary],
            quotaSortSettings: .init(),
            accountUsageMode: .aggregateGateway
        )

        let observedQueue = DispatchQueue(label: "OpenAIAccountGatewayServiceTests.observed")
        var forwardedURLs: [String] = []
        var forwardedAuthorizations: [String] = []
        var forwardedAccountIDs: [String] = []
        var forwardedOriginators: [String] = []
        var forwardedBodies: [[String: Any]] = []

        MockURLProtocol.handler = { request in
            let url = request.url?.absoluteString ?? ""
            let authorization = request.value(forHTTPHeaderField: "authorization") ?? ""
            let accountID = request.value(forHTTPHeaderField: "chatgpt-account-id") ?? ""
            let originator = request.value(forHTTPHeaderField: "originator") ?? ""
            let bodyData =
                request.httpBody ??
                (URLProtocol.property(
                    forKey: OpenAIAccountGatewayService.mockRequestBodyPropertyKey,
                    in: request
                ) as? Data) ??
                Data()
            let body =
                (try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]) ??
                [:]

            observedQueue.sync {
                forwardedURLs.append(url)
                forwardedAuthorizations.append(authorization)
                forwardedAccountIDs.append(accountID)
                forwardedOriginators.append(originator)
                forwardedBodies.append(body)
            }

            let statusCode: Int
            let payload: String
            switch authorization {
            case "Bearer token-alpha":
                statusCode = 429
                payload = "retry alpha"
            case "Bearer token-beta":
                statusCode = 200
                payload = "data: ok\n\n"
            default:
                statusCode = 500
                payload = "unexpected"
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return (response, Data(payload.utf8))
        }

        let firstResponse = try await self.postToGateway(
            service: service,
            stickyKey: "session-1",
            body: """
            {"model":"gpt-5.4","input":[{"role":"user","content":[{"type":"input_text","text":"hello"}]}],"max_output_tokens":128,"temperature":0.7,"top_p":0.9,"stream":false}
            """
        )
        let secondResponse = try await self.postToGateway(
            service: service,
            stickyKey: "session-1",
            body: """
            {"model":"gpt-5.4","input":[{"role":"user","content":[{"type":"input_text","text":"again"}]}],"max_output_tokens":64,"temperature":0.2,"top_p":0.5}
            """
        )

        XCTAssertEqual(firstResponse.statusCode, 200)
        XCTAssertEqual(firstResponse.body, "data: ok\n\n")
        XCTAssertEqual(secondResponse.statusCode, 200)
        XCTAssertEqual(secondResponse.body, "data: ok\n\n")

        let observed = observedQueue.sync {
            (
                forwardedURLs,
                forwardedAuthorizations,
                forwardedAccountIDs,
                forwardedOriginators,
                forwardedBodies
            )
        }

        XCTAssertEqual(
            observed.0,
            [
                "https://example.invalid/v1/responses",
                "https://example.invalid/v1/responses",
                "https://example.invalid/v1/responses",
            ]
        )
        XCTAssertEqual(
            observed.1,
            ["Bearer token-alpha", "Bearer token-beta", "Bearer token-beta"]
        )
        XCTAssertEqual(
            observed.2,
            ["openai-alpha", "openai-beta", "openai-beta"]
        )
        XCTAssertEqual(
            observed.3,
            ["codexbar", "codexbar", "codexbar"]
        )
        XCTAssertEqual(service.currentRoutedAccountIDForTesting(), "acct-beta")

        self.assertNormalizedBody(observed.4[0], expectedText: "hello")
        self.assertNormalizedBody(observed.4[1], expectedText: "hello")
        self.assertNormalizedBody(observed.4[2], expectedText: "again")
    }

    private func postToGateway(
        service: OpenAIAccountGatewayService,
        stickyKey: String,
        body: String
    ) async throws -> (statusCode: Int, body: String) {
        let request = try XCTUnwrap(
            service.parseRequestForTesting(
                from: self.rawRequest(
                    lines: [
                        "POST /v1/responses HTTP/1.1",
                        "Host: 127.0.0.1:1456",
                        "Content-Type: application/json",
                        "Authorization: Bearer \(OpenAIAccountGatewayConfiguration.apiKey)",
                        "chatgpt-account-id: local-placeholder",
                        "session_id: \(stickyKey)",
                        "Content-Length: \(Data(body.utf8).count)",
                        "Connection: close",
                    ],
                    body: body
                )
            )
        )

        let response = try await service.postResponsesProbeForTesting(request: request)
        return (response.statusCode, String(data: response.body, encoding: .utf8) ?? "")
    }

    private func rawRequest(lines: [String], body: String = "") -> Data {
        var text = lines.joined(separator: "\r\n")
        text += "\r\n\r\n"
        text += body
        return Data(text.utf8)
    }

    private func assertNormalizedBody(_ body: [String: Any], expectedText: String) {
        XCTAssertEqual(body["model"] as? String, "gpt-5.4")
        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["instructions"] as? String, "")
        XCTAssertEqual(body["parallel_tool_calls"] as? Bool, false)
        XCTAssertNil(body["max_output_tokens"])
        XCTAssertNil(body["temperature"])
        XCTAssertNil(body["top_p"])

        let tools = body["tools"] as? [Any]
        XCTAssertEqual(tools?.count, 0)

        let includes = body["include"] as? [String]
        XCTAssertEqual(includes, ["reasoning.encrypted_content"])

        let text = (((body["input"] as? [[String: Any]])?.first?["content"] as? [[String: Any]])?.first?["text"] as? String)
        XCTAssertEqual(text, expectedText)
    }
}
