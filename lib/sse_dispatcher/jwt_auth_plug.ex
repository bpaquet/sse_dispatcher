defmodule SseDispatcher.PublicInterface.JwtAuthPlug do
  import Plug.Conn
  import Joken

  def init(options), do: options

  def call(conn, _opts) do
    case jwt_token_from_request(conn) do
      {:ok, jwt_token} ->
        case jwt_issuer_and_signer(jwt_token) do
          {:ok, issuer, signer} ->
            validation_rules = %{
              "iss" => %Joken.Claim{
                validate: fn claim_val, _claims, _context -> claim_val == issuer end
              },
              "exp" => %Joken.Claim{
                validate: fn val, _claims, _context -> val > current_time() end
              }
            }

            case verify_and_validate(validation_rules, jwt_token, signer) do
              {:ok, _} -> conn
              {:error, cause} -> conn |> unauthorized(cause)
            end

          {:bad_jwt_token, cause} ->
            conn |> unauthorized(cause)
        end

      {:bad_jwt_token, cause} ->
        conn |> unauthorized(cause)
    end
  end

  # Extract the JWT token from the request
  defp jwt_token_from_request(conn) do
    case conn |> get_req_header("authorization") do
      [authorization] ->
        if String.starts_with?(authorization, "Bearer ") do
          {:ok,
           String.slice(authorization, String.length("Bearer "), String.length(authorization))}
        else
          {:bad_jwt_token, :bad_authorization_header}
        end

      _ ->
        {:bad_jwt_token, :no_authorization_header}
    end
  end

  # Get the JWT signer from the configuration based on the iss claim defined in the JWT token
  defp jwt_issuer_and_signer(jwt_token) do
    case peek_claims(jwt_token) do
      {:ok, %{"iss" => issuer}} ->
        signer = SseDispatcher.Configuration.public_issuer_signers()[issuer]

        if signer != nil do
          {:ok, issuer, signer}
        else
          {:bad_jwt_token, :bad_issuer}
        end

      _ ->
        {:bad_jwt_token, :no_issuer}
    end
  end

  defp unauthorized(conn, cause) do
    conn |> resp(:unauthorized, to_string(inspect(cause))) |> halt
  end
end
